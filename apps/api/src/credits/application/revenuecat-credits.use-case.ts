import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import { HandleRevenueCatWebhookUseCase } from '../../subscriptions/application/subscription.use-cases.js';
import type { RevenueCatEventInput } from '../../subscriptions/domain/subscription.js';
import { CreditLedgerRepository } from '../domain/credit-ledger.repository.js';
import { isRefundEvent, sourceForStore } from '../domain/revenuecat-credits.js';

export type CreditsWebhookResult =
  'granted' | 'debited' | 'duplicate' | 'ignored';

/**
 * Turns RevenueCat purchase events into credit-ledger entries. Idempotent by
 * store transaction id / event id, independent of the subscription handler.
 */
@Injectable()
export class RevenueCatCreditsUseCase {
  private readonly logger = new Logger(RevenueCatCreditsUseCase.name);
  private readonly entitlementId: string;
  private readonly packs: Record<string, number>;
  private readonly planCredits: number;

  constructor(
    private readonly ledger: CreditLedgerRepository,
    private readonly subscriptions: HandleRevenueCatWebhookUseCase,
    config: ConfigService<Env, true>,
  ) {
    this.entitlementId = config.get('REVENUECAT_ENTITLEMENT_ID', {
      infer: true,
    });
    this.packs = config.get('CREDIT_PACKS', { infer: true });
    this.planCredits = config.get('PLAN_CREDITS_PER_PERIOD', { infer: true });
  }

  async execute(
    event: RevenueCatEventInput,
    now = new Date(),
  ): Promise<CreditsWebhookResult> {
    const packCredits =
      event.productId !== null ? (this.packs[event.productId] ?? 0) : 0;
    const isPack = packCredits > 0;
    const isPlanEvent =
      !isPack &&
      (event.type === 'INITIAL_PURCHASE' || event.type === 'RENEWAL') &&
      (event.entitlementIds === null ||
        event.entitlementIds.includes(this.entitlementId));
    const isPackPurchase =
      isPack &&
      (event.type === 'NON_RENEWING_PURCHASE' ||
        event.type === 'INITIAL_PURCHASE');
    const isPackRefund =
      isPack && isRefundEvent(event.type, event.cancelReason);
    if (!isPlanEvent && !isPackPurchase && !isPackRefund) return 'ignored';

    const userId = await this.subscriptions.resolveUserId(event);
    if (!userId) {
      this.logger.warn(
        `Credit event ${event.id} (${event.type}) has no known app user id; ignoring`,
      );
      return 'ignored';
    }
    const source = sourceForStore(event.store);
    const txRef = event.transactionId ?? event.id;

    if (isPlanEvent) {
      if (
        !event.expirationAt ||
        event.expirationAt.getTime() <= now.getTime()
      ) {
        this.logger.warn(
          `Plan event ${event.id} has no future expiration; no credits granted`,
        );
        return 'ignored';
      }
      const outcome = await this.ledger.grantPlanPeriod(userId, {
        periodEnd: event.expirationAt,
        credits: this.planCredits,
        source,
        externalRef: `rc:plan:${event.id}`,
      });
      return outcome === 'APPLIED' ? 'granted' : 'duplicate';
    }

    if (isPackRefund) {
      const result = await this.ledger.debitPack(userId, {
        credits: packCredits,
        source,
        externalRef: `rc:packrefund:${txRef}`,
        now,
      });
      if (result.outcome === 'DUPLICATE') return 'duplicate';
      if (result.debited < packCredits) {
        this.logger.warn(
          `Refund of pack ${event.productId} for user ${userId}: debited ${result.debited} of ${packCredits} (already spent)`,
        );
      }
      return 'debited';
    }

    const outcome = await this.ledger.grantPack(userId, {
      credits: packCredits,
      source,
      externalRef: `rc:pack:${txRef}`,
    });
    return outcome === 'APPLIED' ? 'granted' : 'duplicate';
  }
}
