import { DomainError } from '../../shared/domain/domain-error.js';

export class SubscriptionRequiredError extends DomainError {
  constructor(entitlementId: string) {
    super(
      'PAYMENT_REQUIRED',
      'SUBSCRIPTION_REQUIRED',
      'An active subscription is required to verify statements',
      { entitlementId },
    );
  }
}

export class InvalidWebhookAuthError extends DomainError {
  constructor() {
    super(
      'UNAUTHENTICATED',
      'INVALID_WEBHOOK_AUTH',
      'Invalid webhook authorization',
    );
  }
}
