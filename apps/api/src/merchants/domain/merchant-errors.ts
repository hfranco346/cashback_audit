import { DomainError } from '../../shared/domain/domain-error.js';

export class MerchantNotFoundError extends DomainError {
  constructor() {
    super('NOT_FOUND', 'MERCHANT_NOT_FOUND', 'Merchant not found');
  }
}

export class MerchantNameTakenError extends DomainError {
  constructor() {
    super(
      'CONFLICT',
      'MERCHANT_NAME_TAKEN',
      'You already have a merchant with that name',
    );
  }
}
