import { Injectable } from '@nestjs/common';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import {
  buildRateProposal,
  type RateProposal,
} from '../domain/rate-proposal.js';
import {
  proposeRewardConversion,
  proposeSpendConversions,
  resolveRewardCurrency,
} from '../domain/reward-currency.js';
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
  ): Promise<RateProposal> {
    const card = await this.cards.findById(userId, verification.cardId);
    if (!card) {
      return { entries: [], rewardConversion: null, spendConversions: [] };
    }
    const categories = await this.categories.listWithCounts(userId);
    const entries = buildRateProposal({
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
    const printedRates = verification.conversion.statementRates;
    const rewardCurrency = resolveRewardCurrency({
      rewardUnit: card.rewardUnit,
      cardRewardCurrency: card.rewardCurrency,
      programCurrency: verification.loyalty.selected?.currency ?? null,
      primaryCurrency: verification.primaryCurrency,
    });
    return {
      entries,
      rewardConversion: proposeRewardConversion({
        primaryCurrency: verification.primaryCurrency,
        rewardCurrency,
        printedRates,
      }),
      spendConversions: proposeSpendConversions({
        primaryCurrency: verification.primaryCurrency,
        lines: verification.transactions,
        printedRates,
      }),
    };
  }
}
