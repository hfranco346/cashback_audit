import { DomainError } from '../../shared/domain/domain-error.js';

export class CardNotFoundError extends DomainError {
  constructor() {
    super('NOT_FOUND', 'CARD_NOT_FOUND', 'Card not found');
  }
}

export class DuplicateRuleCategoryError extends DomainError {
  constructor(categoryId: string) {
    super(
      'VALIDATION',
      'DUPLICATE_RULE_CATEGORY',
      'A card can have only one rule per category',
      {
        categoryId,
      },
    );
  }
}
