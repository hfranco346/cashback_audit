import { DomainError } from '../../shared/domain/domain-error.js';

export class InvalidWebhookAuthError extends DomainError {
  constructor() {
    super(
      'UNAUTHENTICATED',
      'INVALID_WEBHOOK_AUTH',
      'Invalid webhook authorization',
    );
  }
}
