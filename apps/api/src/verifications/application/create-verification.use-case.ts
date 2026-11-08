import { Injectable } from '@nestjs/common';
import { Decimal } from 'decimal.js';
import { CardRepository } from '../../cards/domain/card.repository.js';
import { CardNotFoundError } from '../../cards/domain/card-errors.js';
import { CategoryRepository } from '../../categories/domain/category.repository.js';
import { MerchantRepository } from '../../merchants/domain/merchant.repository.js';
import {
  MerchantMatcher,
  type MatchableMerchant,
} from '../domain/merchant-matcher.js';
import {
  calculateExpectedReward,
  compareReward,
} from '../domain/reward-calculator.js';
import type { MerchantCandidate } from '../domain/statement.js';
import {
  MerchantClassifier,
  StatementExtractor,
} from '../domain/statement-extractor.js';
import {
  InvalidPdfError,
  ReportedRewardMissingError,
} from '../domain/verification-errors.js';
import type {
  MatchSource,
  Verification,
  VerificationBreakdownLine,
  VerificationTransaction,
  VerificationWarning,
} from '../domain/verification.js';
import { VerificationRepository } from '../domain/verification.repository.js';

/** AI guesses below this confidence are ignored. */
export const AI_MATCH_MIN_CONFIDENCE = 0.6;

export interface CreateVerificationInput {
  userId: string;
  cardId: string;
  /** The uploaded PDF; held in memory only. */
  pdf: Buffer;
  reportedRewardOverride?: string;
}

const PDF_MAGIC = Buffer.from('%PDF-');

@Injectable()
export class CreateVerificationUseCase {
  constructor(
    private readonly cards: CardRepository,
    private readonly categories: CategoryRepository,
    private readonly merchants: MerchantRepository,
    private readonly extractor: StatementExtractor,
    private readonly classifier: MerchantClassifier,
    private readonly verifications: VerificationRepository,
  ) {}

  async execute(input: CreateVerificationInput): Promise<Verification> {
    if (
      input.pdf.length < PDF_MAGIC.length ||
      !input.pdf.subarray(0, 5).equals(PDF_MAGIC)
    ) {
      throw new InvalidPdfError();
    }
    const card = await this.cards.findById(input.userId, input.cardId);
    if (!card) throw new CardNotFoundError();

    const userMerchants = await this.merchants.list(input.userId, {});
    const categoryIds = [...new Set(userMerchants.map((m) => m.categoryId))];
    const ruleCategoryIds = card.rules.map((r) => r.categoryId);
    const categories = await this.categories.findManyByIds(input.userId, [
      ...new Set([...categoryIds, ...ruleCategoryIds]),
    ]);
    const categoryName = new Map(categories.map((c) => [c.id, c.name]));
    const merchantById = new Map(userMerchants.map((m) => [m.id, m]));

    const { statement, model } = await this.extractor.extract(input.pdf);
    const warnings: VerificationWarning[] = [];

    // --- reported reward -------------------------------------------------
    let reportedAmount: Decimal;
    let reportedLabel: string | null = null;
    let reportedSource: 'STATEMENT' | 'OVERRIDE';
    if (input.reportedRewardOverride !== undefined) {
      reportedAmount = new Decimal(input.reportedRewardOverride);
      reportedSource = 'OVERRIDE';
    } else if (statement.reportedReward) {
      reportedAmount = statement.reportedReward.amount;
      reportedLabel = statement.reportedReward.label;
      reportedSource = 'STATEMENT';
      const statementUnitIsPoints = statement.reportedReward.unit === 'POINTS';
      if (statementUnitIsPoints !== (card.rewardUnit === 'POINTS')) {
        warnings.push({
          code: 'REPORTED_UNIT_DIFFERS_FROM_CARD',
          message: `The statement reports the reward in ${statement.reportedReward.unit}, but the card is configured as ${card.rewardUnit}. The card configuration was used.`,
        });
      }
    } else {
      throw new ReportedRewardMissingError();
    }

    // --- sanity warnings -----------------------------------------------
    if (statement.cardLast4 && statement.cardLast4 !== card.last4) {
      warnings.push({
        code: 'CARD_LAST4_MISMATCH',
        message: `The statement belongs to a card ending in ${statement.cardLast4}, but you selected a card ending in ${card.last4}.`,
      });
    }
    if (statement.currency && statement.currency !== card.currency) {
      warnings.push({
        code: 'CURRENCY_MISMATCH',
        message: `The statement currency (${statement.currency}) differs from the card currency (${card.currency}).`,
      });
    }
    if (statement.transactions.length === 0) {
      warnings.push({
        code: 'NO_TRANSACTIONS',
        message: 'No transactions were found on the statement.',
      });
    }

    // --- merchant matching: deterministic first, AI for the rest ---------
    const matchable: MatchableMerchant[] = userMerchants.map((m) => ({
      id: m.id,
      name: m.name,
      keywords: m.keywords,
      categoryId: m.categoryId,
    }));
    const matcher = new MerchantMatcher(matchable);
    const matches = statement.transactions.map((tx) => {
      const merchant = matcher.match(tx.merchant);
      return {
        merchantId: merchant?.id ?? null,
        source: (merchant ? 'KEYWORD' : 'NONE') as MatchSource,
        confidence: null as number | null,
      };
    });

    const unmatchedDescriptors = [
      ...new Set(
        statement.transactions
          .filter((_, i) => matches[i]!.merchantId === null)
          .map((t) => t.merchant),
      ),
    ];
    if (unmatchedDescriptors.length > 0 && userMerchants.length > 0) {
      try {
        const candidates: MerchantCandidate[] = userMerchants.map((m) => ({
          id: m.id,
          name: m.name,
          keywords: m.keywords,
          categoryName: categoryName.get(m.categoryId) ?? '',
        }));
        const guesses = await this.classifier.classify(
          unmatchedDescriptors,
          candidates,
        );
        const byDescriptor = new Map(guesses.map((g) => [g.descriptor, g]));
        statement.transactions.forEach((tx, i) => {
          if (matches[i]!.merchantId !== null) return;
          const guess = byDescriptor.get(tx.merchant);
          if (
            guess?.merchantId &&
            merchantById.has(guess.merchantId) &&
            guess.confidence >= AI_MATCH_MIN_CONFIDENCE
          ) {
            matches[i] = {
              merchantId: guess.merchantId,
              source: 'AI',
              confidence: guess.confidence,
            };
          }
        });
      } catch {
        warnings.push({
          code: 'AI_MATCHING_UNAVAILABLE',
          message:
            'Fuzzy merchant matching was unavailable; only keyword matches were applied.',
        });
      }
    }

    // --- reward computation -------------------------------------------------
    const calculation = calculateExpectedReward(
      {
        rewardUnit: card.rewardUnit,
        pointsPerCurrencyUnit: card.pointsPerCurrencyUnit,
        baseRatePercent: card.baseRatePercent,
        rules: card.rules,
      },
      statement.transactions.map((tx, index) => ({
        index,
        amount: tx.amount,
        isCredit: tx.isCredit,
        categoryId: matches[index]!.merchantId
          ? (merchantById.get(matches[index]!.merchantId!)?.categoryId ?? null)
          : null,
      })),
    );

    const net = statement.transactions.reduce(
      (sum, tx) => (tx.isCredit ? sum.minus(tx.amount) : sum.plus(tx.amount)),
      new Decimal(0),
    );
    if (
      statement.totalSpent &&
      net
        .minus(statement.totalSpent)
        .abs()
        .gt(Decimal.max(1, statement.totalSpent.abs().mul('0.01')))
    ) {
      warnings.push({
        code: 'TOTAL_SPENT_MISMATCH',
        message: `The extracted transactions add up to ${net.toFixed(2)} but the statement reports total purchases of ${statement.totalSpent.toFixed(2)}. Some transactions may be missing.`,
      });
    }

    const comparison = compareReward(reportedAmount, calculation.expectedTotal);

    const transactions: VerificationTransaction[] = statement.transactions.map(
      (tx, index) => {
        const match = matches[index]!;
        const merchant = match.merchantId
          ? merchantById.get(match.merchantId)!
          : null;
        const detail = calculation.transactions[index]!;
        return {
          index,
          date: tx.date,
          merchant: tx.merchant,
          amount: tx.amount,
          isCredit: tx.isCredit,
          matchedMerchantId: merchant?.id ?? null,
          matchedMerchantName: merchant?.name ?? null,
          categoryId: merchant?.categoryId ?? null,
          categoryName: merchant
            ? (categoryName.get(merchant.categoryId) ?? null)
            : null,
          matchSource: match.source,
          matchConfidence: match.confidence,
          appliedRatePercent: detail.appliedRatePercent,
          ruleApplied: detail.ruleApplied,
          expectedReward: detail.expectedReward,
        };
      },
    );
    const breakdown: VerificationBreakdownLine[] = calculation.breakdown.map(
      (line) => ({
        ...line,
        categoryName: line.categoryId
          ? (categoryName.get(line.categoryId) ?? null)
          : null,
      }),
    );

    return this.verifications.create({
      userId: input.userId,
      cardId: card.id,
      statementBank: statement.bank,
      statementLast4: statement.cardLast4,
      periodStart: statement.periodStart,
      periodEnd: statement.periodEnd,
      currency: statement.currency ?? card.currency,
      totalSpent: statement.totalSpent,
      totalToPay: statement.totalToPay,
      reportedAmount,
      reportedUnit: card.rewardUnit,
      reportedLabel,
      reportedSource,
      expectedAmount: calculation.expectedTotal,
      difference: comparison.difference,
      tolerance: comparison.tolerance,
      verdict: comparison.verdict,
      breakdown,
      transactions,
      warnings,
      model,
    });
  }
}
