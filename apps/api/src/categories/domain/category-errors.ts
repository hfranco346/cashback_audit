import { DomainError } from '../../shared/domain/domain-error.js';

export class CategoryNotFoundError extends DomainError {
  constructor() {
    super('NOT_FOUND', 'CATEGORY_NOT_FOUND', 'Category not found');
  }
}

export class CategoryNameTakenError extends DomainError {
  constructor() {
    super(
      'CONFLICT',
      'CATEGORY_NAME_TAKEN',
      'You already have a category with that name',
    );
  }
}

export class CategoryInUseError extends DomainError {
  constructor(usage: { merchants: number; cardRules: number }) {
    super(
      'CONFLICT',
      'CATEGORY_IN_USE',
      'Category still has merchants or card rules; pass ?reassignTo=<categoryId> to move them',
      usage,
    );
  }
}
