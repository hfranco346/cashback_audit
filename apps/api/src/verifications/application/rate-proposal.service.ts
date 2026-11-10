import { Injectable } from '@nestjs/common';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import { proposeProgramChoice } from '../domain/loyalty-program-selector.js';
import {
  buildRateProposal,
  type RateProposal,
} from '../domain/rate-proposal.js';
import {
  proposeRewardConversion,
  proposeSpendConversions,
  resolveRewardCurrency,
} from '../domain/reward-currency.js';
import { proposeSuggestedCategories } from '../domain/statement-hints.js';
import { REWARD_ELIGIBLE_KINDS } from '../domain/statement.js';
import type { Verification } from '../domain/verification.js';
import { RewardReportingService } from './reward-reporting.service.js';

/** Builds the rate proposal of a verification from its current data. */
@Injectable()
export class RateProposalService {
  constructor(
    private readonly cards: CardRepository,
    private readonly categories: CategoryRepository,
    private readonly reporting: RewardReportingService,
  ) {}

  async forVerification(
    userId: string,
    verification: Verification,
  ): Promise<RateProposal> {
    const card = await this.cards.findById(userId, verification.cardId);
    if (!card) {
      return {
        entries: [],
        rewardConversion: null,
        spendConversions: [],
        suggestedCategories: [],
        rewardReporting: null,
        rewardProgramChoice: null,
      };
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
    const rewardConversion = proposeRewardConversion({
      primaryCurrency: verification.primaryCurrency,
      rewardCurrency,
      printedRates,
    });
    const spendConversions = proposeSpendConversions({
      primaryCurrency: verification.primaryCurrency,
      lines: verification.transactions,
      printedRates,
    });
    return {
      entries,
      rewardProgramChoice:
        verification.status === 'AWAITING_RATES'
          ? proposeProgramChoice(
              verification.loyalty.programs,
              verification.loyalty.requestedProgramName,
              card.rewardProgramName,
            )
          : null,
      rewardConversion,
      rewardReporting: await this.reporting.buildProposal(
        userId,
        verification,
        card,
        { entries, rewardConversion, spendConversions },
      ),
      suggestedCategories: proposeSuggestedCategories(
        verification.detectedRates,
        verification.transactions,
      ),
      spendConversions,
    };
  }
}
