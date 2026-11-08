import { Injectable } from '@nestjs/common';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import {
  buildRateProposal,
  type RateProposalEntry,
} from '../domain/rate-proposal.js';
import { REWARD_ELIGIBLE_KINDS } from '../domain/statement.js';
import type { Verification } from '../domain/verification.js';

/** Builds the rate proposal of a verification from its current data. */
@Injectable()
export class RateProposalService {
  constructor(
    private readonly cards: CardRepository,
    private readonly categories: CategoryRepository,
  ) {}

  async forVerification(
    userId: string,
    verification: Verification,
  ): Promise<RateProposalEntry[]> {
    const card = await this.cards.findById(userId, verification.cardId);
    if (!card) return [];
    const categories = await this.categories.listWithCounts(userId);
    return buildRateProposal({
      baseRatePercent: card.baseRatePercent,
      rules: card.rules,
      detectedRates: verification.detectedRates,
      categoryNames: new Map(categories.map((c) => [c.id, c.name])),
      usedCategoryIds: verification.transactions
        .filter(
          (t) =>
            REWARD_ELIGIBLE_KINDS.includes(t.kind) && t.categoryId !== null,
        )
        .map((t) => t.categoryId!),
    });
  }
}
