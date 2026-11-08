import type {
  CreditBalance,
  CreditBucket,
  CreditReason,
  CreditSource,
  EntryDraft,
} from './credit-ledger.js';

export interface LedgerEntry {
  id: string;
  delta: number;
  bucket: CreditBucket;
  reason: CreditReason;
  source: CreditSource;
  verificationId: string | null;
  periodEnd: Date | null;
  createdAt: Date;
}

/** A consumed credit; handing it back refunds exactly that credit. */
export interface Reservation {
  entryId: string;
  userId: string;
  draft: EntryDraft;
  verificationId: string | null;
}

export type GrantOutcome = 'APPLIED' | 'DUPLICATE' | 'NOTHING';

/**
 * Every operation is atomic and serialized per user (row lock), so concurrent
 * requests can never spend the same credit twice.
 */
export abstract class CreditLedgerRepository {
  abstract balance(userId: string, now: Date): Promise<CreditBalance>;
  abstract history(
    userId: string,
    skip: number,
    take: number,
  ): Promise<{ items: LedgerEntry[]; total: number }>;
  /** Grants the lifetime free credit once (idempotent). */
  abstract ensureFree(userId: string, credits: number): Promise<void>;
  /**
   * Spends one credit (FREE -> PLAN -> PURCHASED) and returns the reservation,
   * or the current balance when there is nothing to spend.
   */
  abstract reserve(
    userId: string,
    params: { now: Date; freeCredits: number; verificationId: string | null },
  ): Promise<
    | { ok: true; reservation: Reservation }
    | { ok: false; balance: CreditBalance }
  >;
  /** Gives the credit back; idempotent per reservation. */
  abstract refund(reservation: Reservation): Promise<void>;
  /** New billing period: expires the previous one and grants `credits`. */
  abstract grantPlanPeriod(
    userId: string,
    params: {
      periodEnd: Date;
      credits: number;
      source: CreditSource;
      externalRef: string;
    },
  ): Promise<GrantOutcome>;
  abstract grantPack(
    userId: string,
    params: { credits: number; source: CreditSource; externalRef: string },
  ): Promise<GrantOutcome>;
  /** Debits a refunded pack, capped at the purchased balance. */
  abstract debitPack(
    userId: string,
    params: {
      credits: number;
      source: CreditSource;
      externalRef: string;
      now: Date;
    },
  ): Promise<{ outcome: GrantOutcome; debited: number }>;
}
