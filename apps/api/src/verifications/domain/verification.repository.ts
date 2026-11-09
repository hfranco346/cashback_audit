import type {
  NewVerification,
  VerificationStatus,
  VerificationUpdate,
  Verification,
  VerificationSummary,
} from './verification.js';

export interface VerificationPage {
  items: VerificationSummary[];
  total: number;
}

export abstract class VerificationRepository {
  abstract create(input: NewVerification): Promise<Verification>;
  abstract findById(userId: string, id: string): Promise<Verification | null>;
  abstract update(
    userId: string,
    id: string,
    patch: VerificationUpdate,
    /** Only apply while the verification still has this status. */
    options?: { onlyIfStatus?: VerificationStatus },
  ): Promise<Verification | null>;
  /** Newest first. */
  abstract list(
    userId: string,
    filter: {
      cardId?: string;
      status?: VerificationStatus;
      skip: number;
      take: number;
    },
  ): Promise<VerificationPage>;
  /**
   * What needs the user's attention, newest first: PROCESSING, AWAITING_RATES
   * and FAILED/COMPLETED results not seen yet.
   */
  abstract listAttention(userId: string): Promise<VerificationSummary[]>;
  /** Sets `seenAt` once (idempotent). False when the verification is not the user's. */
  abstract markSeen(userId: string, id: string, at: Date): Promise<boolean>;
  /** Every PROCESSING verification (boot recovery), regardless of owner. */
  abstract listProcessing(): Promise<{ id: string; userId: string }[]>;
  abstract delete(userId: string, id: string): Promise<boolean>;
  /** Deletes AWAITING_RATES verifications created before `cutoff`. */
  abstract deleteAwaitingCreatedBefore(cutoff: Date): Promise<number>;
}
