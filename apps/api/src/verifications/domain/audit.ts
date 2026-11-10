import { Decimal } from 'decimal.js';
import {
  looksCumulative,
  selectLoyaltyProgram,
  type ProgramSelection,
} from './loyalty-program-selector.js';
import {
  calculateExpectedReward,
  compareReward,
  convertRewardToCurrency,
  type ConversionRate,
  type RewardCapApplied,
} from './reward-calculator.js';
import {
  deriveEarned,
  expiredInPeriod,
  programBalance,
  type PreviousBalance,
  type RewardReportingMode,
  type VerificationRewardReporting,
} from './reward-reporting.js';
import { statementRatesToPrimary } from './exchange-rates.js';
import { resolveRewardCurrency } from './reward-currency.js';
import type {
  CalculatorRewardUnit,
  RewardRuleConfig,
} from './reward-calculator.js';
import type { LoyaltyProgram, StatementExchangeRate } from './statement.js';
import type { AuditFacts } from './statement-extractor.js';
import {
  PreviousBalanceRequiredError,
  ReportedRewardMissingError,
  RewardExchangeRateRequiredError,
  RewardProgramAmbiguousError,
} from './verification-errors.js';
import type {
  AppliedRewardRate,
  Verification,
  VerificationBreakdownLine,
  VerificationConversion,
  VerificationLoyalty,
  VerificationTransaction,
  VerificationWarning,
} from './verification.js';

/** Warning codes produced by the audit (recomputed on every confirm). */
export const AUDIT_WARNING_CODES: readonly string[] = [
  'NO_EXCHANGE_RATE',
  'EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES',
  'REPORTED_VALUE_MAY_BE_CUMULATIVE',
  'REPORTED_UNIT_DIFFERS_FROM_CARD',
  'REWARD_BALANCE_INCONSISTENT',
  'EXPLANATION_UNAVAILABLE',
];

export interface AuditInput {
  card: {
    currency: string;
    rewardUnit: CalculatorRewardUnit;
    pointsPerCurrencyUnit: Decimal;
    /** Explicit reward currency; wins over the program's currency. */
    rewardCurrency: string | null;
    /** Card-wide reward cap per statement; null = none. */
    rewardCap?: Decimal | null;
  };
  /** Rates to audit with; they replace the card rules entirely. */
  rates: { baseRatePercent: Decimal; rules: RewardRuleConfig[] };
  transactions: VerificationTransaction[];
  categoryNames: Map<string, string>;
  programs: LoyaltyProgram[];
  /** Request/confirm name, then the card's configured name. */
  requestedProgramName: string | null;
  cardProgramName: string | null;
  reportedOverride: Decimal | null;
  /** Rate without a currency: applied to any foreign currency. */
  requestedRate: Decimal | null;
  /** Per foreign currency: primary units per 1 foreign unit. */
  requestedRates: Record<string, Decimal>;
  /** Primary units per 1 reward-currency unit. */
  requestedRewardRate: Decimal | null;
  statementRates: StatementExchangeRate[];
  /**
   * How the bank reports the reward. Null / MONTHLY: the printed figure is
   * what was earned. CUMULATIVE: it is a running balance and the earned amount
   * is derived from `previous` (or from the statement's own earned figure).
   */
  rewardReporting?: {
    mode: RewardReportingMode;
    previous: PreviousBalance | null;
  } | null;
}

export interface AuditResult {
  rewardReporting: VerificationRewardReporting;
  /** Currency of reported/expected/difference/tolerance; null for points. */
  rewardCurrency: string | null;
  /** Expected reward in the primary currency (== expectedAmount if no conversion). */
  expectedInPrimary: Decimal;
  /** Card-wide cap that reduced the expected total; null if it did not apply. */
  rewardCapApplied: RewardCapApplied | null;
  rewardExchangeRate: AppliedRewardRate | null;
  reportedAmount: Decimal;
  reportedLabel: string | null;
  reportedSource: 'STATEMENT' | 'OVERRIDE';
  expectedAmount: Decimal;
  difference: Decimal;
  tolerance: Decimal;
  verdict: NonNullable<Verification['verdict']>;
  breakdown: VerificationBreakdownLine[];
  transactions: VerificationTransaction[];
  conversion: VerificationConversion;
  loyalty: VerificationLoyalty;
  warnings: VerificationWarning[];
}

/**
 * Deterministic audit of an extracted statement: conversion, rewards, caps,
 * comparison with the reported reward. Pure apart from the domain errors it
 * throws (REWARD_PROGRAM_AMBIGUOUS, REPORTED_REWARD_NOT_FOUND). Every number is
 * computed here with exact decimals; no LLM is involved.
 */
export function computeAudit(input: AuditInput): AuditResult {
  const { card } = input;
  const warnings: VerificationWarning[] = [];

  // --- loyalty program + reported reward ---------------------------------
  const selection: ProgramSelection = selectLoyaltyProgram(
    input.programs,
    input.requestedProgramName,
    input.cardProgramName,
  );
  const program = selection.status === 'SELECTED' ? selection.program : null;
  const cumulative = input.rewardReporting?.mode === 'CUMULATIVE';
  let reportedAmount: Decimal;
  let reportedSource: 'STATEMENT' | 'OVERRIDE';
  let reporting: VerificationRewardReporting | null = null;
  if (input.reportedOverride) {
    reportedAmount = input.reportedOverride;
    reportedSource = 'OVERRIDE';
  } else if (selection.status === 'AMBIGUOUS') {
    throw new RewardProgramAmbiguousError(
      selection.names,
      selection.requestedName,
    );
  } else if (
    program &&
    (cumulative ? programBalance(program) : program.accumulated)
  ) {
    if (cumulative) {
      reporting = deriveCumulative(
        program,
        input.rewardReporting?.previous ?? null,
      );
      reportedAmount = reporting.earned!;
      if (reportedAmount.isNegative()) {
        warnings.push({
          code: 'REWARD_BALANCE_INCONSISTENT',
          message: `"${program.name}": current balance ${reporting.currentBalance?.toString()} minus previous balance ${reporting.previousBalance?.toString() ?? '?'} plus redeemed ${reporting.redeemedInPeriod.toString()} plus expired ${reporting.expiredInPeriod.toString()} is negative (${reportedAmount.toString()}). Check the previous balance.`,
        });
      }
    } else {
      reportedAmount = program.accumulated!;
    }
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

  // --- conversion + reward ---------------------------------------------
  const printedRates = statementRatesToPrimary(
    input.statementRates,
    card.currency,
  );
  const rewardCurrency = resolveRewardCurrency({
    rewardUnit: card.rewardUnit,
    cardRewardCurrency: card.rewardCurrency,
    programCurrency: program?.currency ?? null,
    primaryCurrency: card.currency,
  });
  const needsRewardConversion =
    rewardCurrency !== null && rewardCurrency !== card.currency;

  // Reward rate: explicit > the user's spend rate for that currency > printed.
  let rewardRate: AppliedRewardRate | null = null;
  if (needsRewardConversion) {
    const printed = printedRates.find((r) => r.from === rewardCurrency);
    const chosen =
      input.requestedRewardRate ?? input.requestedRates[rewardCurrency] ?? null;
    let rate: Decimal | null = null;
    let source: AppliedRewardRate['source'] = 'USER_ENTERED';
    if (chosen) {
      rate = chosen;
      if (
        printed &&
        chosen.toDecimalPlaces(6).eq(printed.rate.toDecimalPlaces(6))
      ) {
        source = 'STATEMENT_CONFIRMED';
      }
    } else if (printed) {
      rate = printed.rate;
      source = 'STATEMENT_CONFIRMED';
    }
    if (!rate) {
      throw new RewardExchangeRateRequiredError(card.currency, rewardCurrency);
    }
    rewardRate = {
      fromCurrency: card.currency,
      toCurrency: rewardCurrency,
      rate,
      source,
    };
  }

  const rates: ConversionRate[] = [
    ...Object.entries(input.requestedRates).map(([from, rate]) => ({
      from,
      rate,
      source: 'REQUEST' as const,
    })),
    ...(input.requestedRewardRate && rewardCurrency
      ? [
          {
            from: rewardCurrency,
            rate: input.requestedRewardRate,
            source: 'REQUEST' as const,
          },
        ]
      : []),
    ...(input.requestedRate
      ? [
          {
            from: null,
            rate: input.requestedRate,
            source: 'REQUEST' as const,
          },
        ]
      : []),
    ...printedRates,
  ];
  const calculation = calculateExpectedReward(
    {
      currency: card.currency,
      rewardUnit: card.rewardUnit,
      pointsPerCurrencyUnit: card.pointsPerCurrencyUnit,
      baseRatePercent: input.rates.baseRatePercent,
      rules: input.rates.rules,
      rewardCap: card.rewardCap ?? null,
    },
    input.transactions.map((tx) => ({
      index: tx.index,
      amount: tx.amount,
      currency: tx.currency,
      kind: tx.kind,
      isCredit: tx.isCredit,
      categoryId: tx.categoryId,
    })),
    rates,
  );
  const expectedAmount = rewardRate
    ? convertRewardToCurrency(
        calculation.expectedTotalExact,
        rewardRate.rate,
        rewardRate.toCurrency,
      )
    : calculation.expectedTotal;

  const missingRate = calculation.currencies.filter((c) => c.excludedCount > 0);
  if (missingRate.length > 0) {
    const count = missingRate.reduce((n, c) => n + c.excludedCount, 0);
    warnings.push({
      code: 'NO_EXCHANGE_RATE',
      message: `No exchange rate to ${card.currency} was available for ${missingRate.map((c) => c.currency).join(', ')}; ${count} line(s) were left out of the expected reward. Send exchangeRates ({ "<CURRENCY>": "<${card.currency} per 1 unit>" }) to include them.`,
    });
  }
  const foreignWithRate = calculation.currencies.filter(
    (c) => !c.isPrimary && c.exchangeRate !== null,
  );
  if (input.requestedRate && foreignWithRate.length > 1) {
    warnings.push({
      code: 'EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES',
      message: `The exchangeRate you sent was applied to several currencies (${foreignWithRate.map((c) => c.currency).join(', ')}).`,
    });
  }

  const comparison = compareReward(
    reportedAmount,
    expectedAmount,
    card.rewardUnit === 'POINTS' ? null : (rewardCurrency ?? card.currency),
  );
  if (
    reportedSource === 'STATEMENT' &&
    !cumulative &&
    program &&
    looksCumulative(program, expectedAmount)
  ) {
    warnings.push({
      code: 'REPORTED_VALUE_MAY_BE_CUMULATIVE',
      message: `"${program.name}" reports ${reportedAmount.toString()} accumulated, which looks like a running balance (available + redeemed + forfeited) well above the ${expectedAmount.toString()} expected for this period. Send reportedRewardOverride with the amount earned this period to audit it.`,
    });
  }

  const transactions = input.transactions.map((tx) => {
    const detail = calculation.transactions[tx.index]!;
    return {
      ...tx,
      convertedAmount: detail.convertedAmount,
      exchangeRate: detail.exchangeRate,
      rateSource: detail.rateSource,
      excludedReason: detail.excludedReason,
      appliedRatePercent: detail.appliedRatePercent,
      ruleApplied: detail.ruleApplied,
      expectedReward: detail.expectedReward,
    };
  });
  const breakdown = calculation.breakdown.map((line) => ({
    ...line,
    categoryName: line.categoryId
      ? (input.categoryNames.get(line.categoryId) ?? null)
      : null,
  }));

  return {
    rewardReporting: reporting ?? {
      mode: 'MONTHLY',
      programName: program?.name ?? null,
      reportedLabel: program?.reportedLabel ?? null,
      currentBalance: null,
      previousBalance: null,
      previousBalanceSource: null,
      previousVerificationId: null,
      previousPeriodEnd: null,
      redeemedInPeriod: program?.redeemedInPeriod ?? new Decimal(0),
      expiredInPeriod: program ? expiredInPeriod(program) : new Decimal(0),
      earned: reportedAmount,
    },
    rewardCurrency,
    expectedInPrimary: calculation.expectedTotal,
    rewardCapApplied: calculation.rewardCapApplied,
    rewardExchangeRate: rewardRate,
    reportedAmount,
    reportedLabel: program?.name ?? null,
    reportedSource,
    expectedAmount,
    difference: comparison.difference,
    tolerance: comparison.tolerance,
    verdict: comparison.verdict,
    breakdown,
    transactions,
    conversion: {
      requestedRate: input.requestedRate,
      requestedRates: input.requestedRates,
      requestedRewardRate: input.requestedRewardRate,
      statementRates: input.statementRates,
      currencies: calculation.currencies,
      rewardCapApplied: calculation.rewardCapApplied,
      reward: rewardRate
        ? {
            ...rewardRate,
            expectedInPrimary: calculation.expectedTotal,
          }
        : null,
    },
    loyalty: {
      requestedProgramName: input.requestedProgramName,
      reportedOverride: input.reportedOverride,
      selected: program,
      selectedBy: selection.status === 'SELECTED' ? selection.source : null,
      programs: input.programs,
    },
    warnings,
  };
}

/**
 * Derives what was earned from a running balance:
 * earned = current - previous + redeemed + expired. With no previous balance
 * the statement's own earned-in-period figure is used; with neither the user
 * must provide the previous balance.
 */
function deriveCumulative(
  program: LoyaltyProgram,
  previous: PreviousBalance | null,
): VerificationRewardReporting {
  const currentBalance = programBalance(program)!;
  const redeemed = program.redeemedInPeriod ?? new Decimal(0);
  const expired = expiredInPeriod(program);
  const base = {
    mode: 'CUMULATIVE' as const,
    programName: program.name,
    reportedLabel: program.reportedLabel,
    currentBalance,
    redeemedInPeriod: redeemed,
    expiredInPeriod: expired,
  };
  if (previous) {
    return {
      ...base,
      previousBalance: previous.value,
      previousBalanceSource: previous.source,
      previousVerificationId: previous.previousVerificationId,
      previousPeriodEnd: previous.previousPeriodEnd ?? null,
      earned: deriveEarned({
        currentBalance,
        previousBalance: previous.value,
        redeemedInPeriod: redeemed,
        expiredInPeriod: expired,
      }),
    };
  }
  if (program.earnedInPeriod) {
    return {
      ...base,
      previousBalance: null,
      previousBalanceSource: 'STATEMENT',
      previousVerificationId: null,
      previousPeriodEnd: null,
      earned: program.earnedInPeriod,
    };
  }
  throw new PreviousBalanceRequiredError();
}

/** The numbers of an audit, as strings, for the narrative explainer. */
export function buildAuditFacts(
  audit: AuditResult,
  context: {
    rewardUnit: AuditFacts['rewardUnit'];
    primaryCurrency: string;
  },
): AuditFacts {
  return {
    verdict: audit.verdict,
    rewardUnit: context.rewardUnit,
    primaryCurrency: context.primaryCurrency,
    rewardCurrency: audit.rewardCurrency,
    expectedInPrimaryCurrency: audit.rewardExchangeRate
      ? audit.expectedInPrimary.toString()
      : null,
    reported: audit.reportedAmount.toString(),
    expected: audit.expectedAmount.toString(),
    difference: audit.difference.toString(),
    tolerance: audit.tolerance.toString(),
    programName: audit.reportedLabel,
    reportedSource: audit.reportedSource,
    breakdown: audit.breakdown.map((l) => ({
      category: l.categoryName,
      ratePercent: l.ratePercent.toString(),
      spend: l.spend.toString(),
      expectedReward: l.expectedReward.toString(),
      capped: l.capped,
      monthlyCap: l.monthlyCap?.toString() ?? null,
    })),
    rewardReporting:
      audit.rewardReporting.mode === 'CUMULATIVE'
        ? {
            currentBalance:
              audit.rewardReporting.currentBalance?.toString() ?? null,
            previousBalance:
              audit.rewardReporting.previousBalance?.toString() ?? null,
            previousBalanceSource: audit.rewardReporting.previousBalanceSource,
            redeemedInPeriod: audit.rewardReporting.redeemedInPeriod.toString(),
            expiredInPeriod: audit.rewardReporting.expiredInPeriod.toString(),
            earned: audit.rewardReporting.earned?.toString() ?? null,
          }
        : null,
    rewardCap: audit.rewardCapApplied
      ? {
          cap: audit.rewardCapApplied.cap.toString(),
          uncapped: audit.rewardCapApplied.uncapped.toString(),
          capped: audit.rewardCapApplied.capped.toString(),
        }
      : null,
    excludedForeignLines: audit.conversion.currencies.reduce(
      (n, c) => n + c.excludedCount,
      0,
    ),
    warningCodes: audit.warnings.map((w) => w.code),
  };
}
