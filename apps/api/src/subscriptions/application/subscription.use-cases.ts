import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, timingSafeEqual } from 'node:crypto';
import type { Env } from '../../config/env.js';
import { UserRepository } from '../../users/domain/user.repository.js';
import {
  isEntitled,
  transitionFor,
  type RevenueCatEventInput,
  type Subscription,
} from '../domain/subscription.js';
import {
  InvalidWebhookAuthError,
  SubscriptionRequiredError,
} from '../domain/subscription-errors.js';
import { SubscriptionRepository } from '../domain/subscription.repository.js';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface SubscriptionView {
  entitlementId: string;
  active: boolean;
  /** NONE when the user never subscribed. */
  status: Subscription['status'] | 'NONE';
  expiresAt: Date | null;
  willRenew: boolean;
  store: string | null;
  productId: string | null;
}

@Injectable()
export class GetMySubscriptionUseCase {
  private readonly entitlementId: string;

  constructor(
    private readonly subscriptions: SubscriptionRepository,
    config: ConfigService<Env, true>,
  ) {
    this.entitlementId = config.get('REVENUECAT_ENTITLEMENT_ID', {
      infer: true,
    });
  }

  async execute(userId: string): Promise<SubscriptionView> {
    const sub = await this.subscriptions.find(userId, this.entitlementId);
    return {
      entitlementId: this.entitlementId,
      active: isEntitled(sub),
      status: sub?.status ?? 'NONE',
      expiresAt: sub?.expiresAt ?? null,
      willRenew: sub ? sub.willRenew && isEntitled(sub) : false,
      store: sub?.store ?? null,
      productId: sub?.productId ?? null,
    };
  }
}

/** Throws SubscriptionRequiredError unless the gate is off or the user is entitled. */
@Injectable()
export class RequireSubscriptionUseCase {
  private readonly entitlementId: string;
  private readonly gateEnabled: boolean;

  constructor(
    private readonly subscriptions: SubscriptionRepository,
    config: ConfigService<Env, true>,
  ) {
    this.entitlementId = config.get('REVENUECAT_ENTITLEMENT_ID', {
      infer: true,
    });
    this.gateEnabled = config.get('SUBSCRIPTION_GATE_ENABLED', { infer: true });
  }

  async execute(userId: string): Promise<void> {
    if (!this.gateEnabled) return;
    const sub = await this.subscriptions.find(userId, this.entitlementId);
    if (!isEntitled(sub))
      throw new SubscriptionRequiredError(this.entitlementId);
  }
}

export type WebhookResult = 'applied' | 'duplicate' | 'stale' | 'ignored';

@Injectable()
export class HandleRevenueCatWebhookUseCase {
  private readonly logger = new Logger(HandleRevenueCatWebhookUseCase.name);
  private readonly entitlementId: string;
  private readonly expectedAuth: string;

  constructor(
    private readonly subscriptions: SubscriptionRepository,
    private readonly users: UserRepository,
    config: ConfigService<Env, true>,
  ) {
    this.entitlementId = config.get('REVENUECAT_ENTITLEMENT_ID', {
      infer: true,
    });
    this.expectedAuth = config.get('REVENUECAT_WEBHOOK_AUTH', { infer: true });
  }

  /** Constant-time comparison; an unset secret rejects everything. */
  assertAuthorized(header: string | undefined): void {
    if (!this.expectedAuth || header === undefined)
      throw new InvalidWebhookAuthError();
    const digest = (value: string) =>
      createHash('sha256').update(value).digest();
    if (!timingSafeEqual(digest(header), digest(this.expectedAuth))) {
      throw new InvalidWebhookAuthError();
    }
  }

  async execute(event: RevenueCatEventInput): Promise<WebhookResult> {
    const transition = transitionFor(event.type);
    const relevant =
      event.entitlementIds === null ||
      event.entitlementIds.includes(this.entitlementId);
    if (!transition || !relevant) {
      await this.subscriptions.recordIgnored(
        event,
        null,
        transition ? 'OTHER_ENTITLEMENT' : 'UNHANDLED_TYPE',
      );
      return 'ignored';
    }

    const userId = await this.resolveUserId(event);
    if (!userId) {
      this.logger.warn(
        `RevenueCat event ${event.id} (${event.type}) has no known app user id; ignoring`,
      );
      await this.subscriptions.recordIgnored(event, null, 'UNKNOWN_USER');
      return 'ignored';
    }

    const outcome = await this.subscriptions.applyEvent(
      userId,
      this.entitlementId,
      event,
      transition,
    );
    return outcome.toLowerCase() as WebhookResult;
  }

  /** The RevenueCat app user id must be our user id (`Purchases.logIn(userId)`). */
  private async resolveUserId(
    event: RevenueCatEventInput,
  ): Promise<string | null> {
    for (const candidate of [event.appUserId, ...event.aliases]) {
      if (
        UUID.test(candidate) &&
        (await this.users.findById(candidate.toLowerCase()))
      ) {
        return candidate.toLowerCase();
      }
    }
    return null;
  }
}
