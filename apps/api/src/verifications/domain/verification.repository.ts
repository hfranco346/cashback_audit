import type {
  NewVerification,
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
  /** Newest first. */
  abstract list(
    userId: string,
    filter: { cardId?: string; skip: number; take: number },
  ): Promise<VerificationPage>;
  abstract delete(userId: string, id: string): Promise<boolean>;
}
