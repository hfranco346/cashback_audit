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
  looksCumulative,
  selectLoyaltyProgram,
} from '../domain/loyalty-program-selector.js';
import {
  calculateExpectedReward,
  compareReward,
  type ConversionRate,
} from '../domain/reward-calculator.js';
import {
  REWARD_ELIGIBLE_KINDS,
  type ExtractedStatement,
  type MerchantCandidate,
} from '../domain/statement.js';
import {
  MerchantClassifier,
  StatementExtractor,
} from '../domain/statement-extractor.js';
import {
  InvalidPdfError,
  ReportedRewardMissingError,
  RewardProgramAmbiguousError,
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
  /** Decimal string: 1 unit of the foreign currency in the card currency. */
  exchangeRate?: string;
  /** Loyalty program to audit; overrides the card's `rewardProgramName`. */
  rewardProgramName?: string;
}

const TOTALS_TOLERANCE = (reference: Decimal) =>
  Decimal.max(1, reference.abs().mul('0.01'));

/** Rates usable to reach `primary`, from the statement (inverted if needed). */
function statementRates(
  statement: ExtractedStatement,
  primary: string,
): ConversionRate[] {
  const printed = statement.exchangeRate;
  if (!printed || printed.rate.lte(0)) return [];
  if (printed.to === primary && printed.from !== primary) {
    return [{ from: printed.from, rate: printed.rate, source: 'STATEMENT' }];
  }
  if (printed.from === primary && printed.to !== primary) {
    return [
      {
        from: printed.to,
        rate: new Decimal(1).div(printed.rate),
        source: 'STATEMENT',
      },
    ];
  }
  return [];
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

    // --- loyalty program + reported reward -------------------------------
    const selection = selectLoyaltyProgram(
      statement.loyaltyPrograms,
      input.rewardProgramName,
      card.rewardProgramName,
    );
    const program = selection.status === 'SELECTED' ? selection.program : null;
    let reportedAmount: Decimal;
    let reportedLabel: string | null = program?.name ?? null;
    let reportedSource: 'STATEMENT' | 'OVERRIDE';
    if (input.reportedRewardOverride !== undefined) {
      reportedAmount = new Decimal(input.reportedRewardOverride);
      reportedSource = 'OVERRIDE';
    } else if (selection.status === 'AMBIGUOUS') {
      throw new RewardProgramAmbiguousError(
        selection.names,
        selection.requestedName,
      );
    } else if (program?.accumulated) {
      reportedAmount = program.accumulated;
      reportedSource = 'STATEMENT';
      const programUnit =
        program.unit === 'UNKNOWN'
          ? null
          : program.unit === 'CURRENCY'
            ? 'CURRENCY'
            : 'POINTS';
      if (
        programUnit &&
        programUnit !== (card.rewardUnit === 'POINTS' ? 'POINTS' : 'CURRENCY')
      ) {
        warnings.push({
          code: 'REPORTED_UNIT_DIFFERS_FROM_CARD',
          message: `The statement reports the reward in ${program.unit}, but the card is configured as ${card.rewardUnit}. The card configuration was used.`,
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
    const statementCurrencies = new Set([
      ...statement.transactions.map((t) => t.currency),
      ...statement.summaries.map((s) => s.currency),
    ]);
    if (
      statementCurrencies.size > 0 &&
      !statementCurrencies.has(card.currency)
    ) {
      warnings.push({
        code: 'CURRENCY_MISMATCH',
        message: `The statement currencies (${[...statementCurrencies].join(', ')}) do not include the card currency (${card.currency}).`,
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
    const eligible = statement.transactions.map((tx) =>
      REWARD_ELIGIBLE_KINDS.includes(tx.kind),
    );
    const matches = statement.transactions.map((tx, i) => {
      const merchant = eligible[i] ? matcher.match(tx.merchant) : null;
      return {
        merchantId: merchant?.id ?? null,
        source: (merchant ? 'KEYWORD' : 'NONE') as MatchSource,
        confidence: null as number | null,
      };
    });

    const unmatchedDescriptors = [
      ...new Set(
        statement.transactions
          .filter((_, i) => eligible[i] && matches[i]!.merchantId === null)
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
          if (!eligible[i] || matches[i]!.merchantId !== null) return;
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
    const requestedRate = input.exchangeRate
      ? new Decimal(input.exchangeRate)
      : null;
    const rates: ConversionRate[] = [
      ...(requestedRate
        ? [{ from: null, rate: requestedRate, source: 'REQUEST' as const }]
        : []),
      ...statementRates(statement, card.currency),
    ];
    const calculation = calculateExpectedReward(
      {
        currency: card.currency,
        rewardUnit: card.rewardUnit,
        pointsPerCurrencyUnit: card.pointsPerCurrencyUnit,
        baseRatePercent: card.baseRatePercent,
        rules: card.rules,
      },
      statement.transactions.map((tx, index) => ({
        index,
        amount: tx.amount,
        currency: tx.currency,
        kind: tx.kind,
        isCredit: tx.isCredit,
        categoryId: matches[index]!.merchantId
          ? (merchantById.get(matches[index]!.merchantId!)?.categoryId ?? null)
          : null,
      })),
      rates,
    );

    const missingRate = calculation.currencies.filter(
      (c) => c.excludedCount > 0,
    );
    if (missingRate.length > 0) {
      const count = missingRate.reduce((n, c) => n + c.excludedCount, 0);
      warnings.push({
        code: 'NO_EXCHANGE_RATE',
        message: `No exchange rate to ${card.currency} was available for ${missingRate.map((c) => c.currency).join(', ')}; ${count} line(s) were left out of the expected reward. Send exchangeRate to include them.`,
      });
    }
    const foreignWithRate = calculation.currencies.filter(
      (c) => !c.isPrimary && c.exchangeRate !== null,
    );
    if (requestedRate && foreignWithRate.length > 1) {
      warnings.push({
        code: 'EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES',
        message: `The exchangeRate you sent was applied to several currencies (${foreignWithRate.map((c) => c.currency).join(', ')}).`,
      });
    }

    // Statement totals per currency vs the extracted lines (warn only).
    for (const summary of statement.summaries) {
      const target = summary.purchasesAndCharges;
      if (!target) continue;
      const lines = statement.transactions.filter(
        (t) => t.currency === summary.currency,
      );
      const signed = (kinds: readonly string[]) =>
        lines
          .filter((t) => kinds.includes(t.kind))
          .reduce(
            (sum, t) => (t.isCredit ? sum.minus(t.amount) : sum.plus(t.amount)),
            new Decimal(0),
          );
      const purchasesOnly = signed(['PURCHASE', 'REFUND']);
      const withCharges = signed([
        'PURCHASE',
        'REFUND',
        'FEE',
        'INTEREST',
        'INSURANCE',
        'OTHER',
      ]);
      const tolerance = TOTALS_TOLERANCE(target);
      if (
        purchasesOnly.minus(target).abs().gt(tolerance) &&
        withCharges.minus(target).abs().gt(tolerance)
      ) {
        warnings.push({
          code: 'TOTAL_SPENT_MISMATCH',
          message: `The extracted ${summary.currency} lines add up to ${purchasesOnly.toFixed(2)} (${withCharges.toFixed(2)} with charges) but the statement reports ${target.toFixed(2)}. Some transactions may be missing.`,
        });
      }
    }

    const comparison = compareReward(reportedAmount, calculation.expectedTotal);
    if (
      reportedSource === 'STATEMENT' &&
      program &&
      looksCumulative(program, calculation.expectedTotal)
    ) {
      warnings.push({
        code: 'REPORTED_VALUE_MAY_BE_CUMULATIVE',
        message: `"${program.name}" reports ${reportedAmount.toString()} accumulated, which looks like a running balance (available + redeemed + forfeited) well above the ${calculation.expectedTotal.toString()} expected for this period. Send reportedRewardOverride with the amount earned this period to audit it.`,
      });
    }
    const primarySummary = statement.summaries.find(
      (x) => x.currency === card.currency,
    );

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
          reference: tx.reference,
          merchant: tx.merchant,
          amount: tx.amount,
          currency: tx.currency,
          isCredit: tx.isCredit,
          kind: tx.kind,
          convertedAmount: detail.convertedAmount,
          exchangeRate: detail.exchangeRate,
          rateSource: detail.rateSource,
          excludedReason: detail.excludedReason,
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
      currency: statement.currency,
      primaryCurrency: card.currency,
      totalSpent: primarySummary?.purchasesAndCharges ?? null,
      totalToPay: primarySummary?.totalBalance ?? null,
      summaries: statement.summaries,
      conversion: {
        requestedRate,
        statementRate: statement.exchangeRate,
        currencies: calculation.currencies,
      },
      loyalty: {
        selected: program,
        selectedBy: selection.status === 'SELECTED' ? selection.source : null,
        programs: statement.loyaltyPrograms,
      },
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
