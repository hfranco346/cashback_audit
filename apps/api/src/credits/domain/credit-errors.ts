import { DomainError } from '../../shared/domain/domain-error.js';

export class NoCreditsError extends DomainError {
  constructor(balance: {
    free: number;
    plan: number;
    planPeriodEnd: string | null;
    purchased: number;
    total: number;
    subscriptionActive: boolean;
  }) {
    super(
      'PAYMENT_REQUIRED',
      'NO_CREDITS',
      'No verification credits left. Subscribe or buy a credit pack.',
      balance,
    );
  }
}
