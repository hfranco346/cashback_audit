import { Injectable } from '@nestjs/common';
import { CategoryNotFoundError } from '../../categories/domain/category-errors.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import { REWARD_ELIGIBLE_KINDS } from '../domain/statement.js';
import {
  TransactionNotClassifiableError,
  TransactionNotFoundError,
  VerificationNotFoundError,
  VerificationNotReadyError,
} from '../domain/verification-errors.js';
import type { Verification } from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';

/**
 * Lets the user correct the category of one line (e.g. a wrong AI guess). The
 * stored result is NOT recomputed: confirm again to apply it.
 */
@Injectable()
export class UpdateTransactionCategoryUseCase {
  constructor(
    private readonly verifications: VerificationRepository,
    private readonly categories: CategoryRepository,
  ) {}

  async execute(input: {
    userId: string;
    verificationId: string;
    index: number;
    categoryId: string | null;
  }): Promise<Verification> {
    const verification = await this.verifications.findById(
      input.userId,
      input.verificationId,
    );
    if (!verification) throw new VerificationNotFoundError();
    if (
      verification.status === 'PROCESSING' ||
      verification.status === 'FAILED'
    )
      throw new VerificationNotReadyError();
    const tx = verification.transactions.find((t) => t.index === input.index);
    if (!tx) throw new TransactionNotFoundError();
    if (!REWARD_ELIGIBLE_KINDS.includes(tx.kind))
      throw new TransactionNotClassifiableError();

    let categoryName: string | null = null;
    if (input.categoryId) {
      const [category] = await this.categories.findManyByIds(input.userId, [
        input.categoryId,
      ]);
      if (!category) throw new CategoryNotFoundError();
      categoryName = category.name;
    }

    const transactions = verification.transactions.map((t) =>
      t.index === input.index
        ? {
            ...t,
            categoryId: input.categoryId,
            categoryName,
            matchedMerchantId: null,
            matchedMerchantName: null,
            matchSource: input.categoryId
              ? ('USER' as const)
              : ('NONE' as const),
            matchConfidence: null,
            matchReason: null,
            suggestedHint: null,
          }
        : t,
    );
    const updated = await this.verifications.update(
      input.userId,
      verification.id,
      { transactions },
    );
    if (!updated) throw new VerificationNotFoundError();
    return updated;
  }
}
