import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Env } from '../../config/env.js';
import { GetMySubscriptionUseCase } from '../../subscriptions/application/subscription.use-cases.js';
import type { CreditBalance } from '../domain/credit-ledger.js';
import { NoCreditsError } from '../domain/credit-errors.js';
import {
  CreditLedgerRepository,
  type Reservation,
} from '../domain/credit-ledger.repository.js';

export interface BalanceView extends CreditBalance {
  subscriptionActive: boolean;
}

/**
 * The backend is the source of truth for credits. With the gate disabled
 * (local development) nothing is checked, spent or refunded.
 */
@Injectable()
export class CreditsService {
  private readonly logger = new Logger(CreditsService.name);
  private readonly gateEnabled: boolean;
  private readonly freeCredits: number;

  constructor(
    private readonly ledger: CreditLedgerRepository,
    private readonly subscription: GetMySubscriptionUseCase,
    config: ConfigService<Env, true>,
  ) {
    this.gateEnabled = config.get('CREDITS_GATE_ENABLED', { infer: true });
    this.freeCredits = config.get('FREE_CREDITS', { infer: true });
  }

  /** Called at sign-in; idempotent (one free credit per user, ever). */
  async grantFree(userId: string): Promise<void> {
    await this.ledger.ensureFree(userId, this.freeCredits);
  }

  async balance(userId: string, now = new Date()): Promise<BalanceView> {
    const [balance, subscription] = await Promise.all([
      this.ledger.balance(userId, now),
      this.subscription.execute(userId),
    ]);
    return { ...balance, subscriptionActive: subscription.active };
  }

  async history(userId: string, page: number, pageSize: number) {
    const result = await this.ledger.history(
      userId,
      (page - 1) * pageSize,
      pageSize,
    );
    return { ...result, page, pageSize };
  }

  /** Cheap pre-check (not binding): fails with NO_CREDITS when nothing is left. */
  async assertHasCredits(userId: string): Promise<void> {
    if (!this.gateEnabled) return;
    await this.grantFree(userId);
    const view = await this.balance(userId);
    if (view.total <= 0) throw this.noCredits(view);
  }

  /**
   * Atomically spends one credit before the paid work starts. Returns null
   * when the gate is disabled.
   */
  async reserve(
    userId: string,
    verificationId: string,
  ): Promise<Reservation | null> {
    if (!this.gateEnabled) return null;
    const result = await this.ledger.reserve(userId, {
      now: new Date(),
      freeCredits: this.freeCredits,
      verificationId,
    });
    if (!result.ok) {
      const subscription = await this.subscription.execute(userId);
      throw this.noCredits({
        ...result.balance,
        subscriptionActive: subscription.active,
      });
    }
    return result.reservation;
  }

  /** Gives the reserved credit back after a failure; never throws. */
  async refund(reservation: Reservation | null): Promise<void> {
    if (!reservation) return;
    try {
      await this.ledger.refund(reservation);
    } catch (error) {
      this.logger.error(
        `Could not refund credit ${reservation.entryId}: ${error instanceof Error ? error.name : 'unknown'}`,
      );
    }
  }

  private noCredits(view: BalanceView): NoCreditsError {
    return new NoCreditsError({
      free: view.free,
      plan: view.plan,
      planPeriodEnd: view.planPeriodEnd?.toISOString() ?? null,
      purchased: view.purchased,
      total: view.total,
      subscriptionActive: view.subscriptionActive,
    });
  }
}
