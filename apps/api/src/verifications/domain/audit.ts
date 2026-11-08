import { Decimal } from 'decimal.js';
import {
  looksCumulative,
  selectLoyaltyProgram,
  type ProgramSelection,
} from './loyalty-program-selector.js';
import {
  calculateExpectedReward,
  compareReward,
  type ConversionRate,
} from './reward-calculator.js';
import type {
  CalculatorRewardUnit,
  RewardRuleConfig,
} from './reward-calculator.js';
import type { LoyaltyProgram, StatementExchangeRate } from './statement.js';
import {
  ReportedRewardMissingError,
  RewardProgramAmbiguousError,
} from './verification-errors.js';
import type {
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
];

export interface AuditInput {
  card: {
    currency: string;
    rewardUnit: CalculatorRewardUnit;
    pointsPerCurrencyUnit: Decimal;
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
  requestedRate: Decimal | null;
  statementRate: StatementExchangeRate | null;
}

export interface AuditResult {
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

/** Rates usable to reach `primary`, from the statement (inverted if needed). */
function statementRates(
  printed: StatementExchangeRate | null,
  primary: string,
): ConversionRate[] {
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
  let reportedAmount: Decimal;
  let reportedSource: 'STATEMENT' | 'OVERRIDE';
  if (input.reportedOverride) {
    reportedAmount = input.reportedOverride;
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

  // --- conversion + reward ---------------------------------------------
  const rates: ConversionRate[] = [
    ...(input.requestedRate
      ? [
          {
            from: null,
            rate: input.requestedRate,
            source: 'REQUEST' as const,
          },
        ]
      : []),
    ...statementRates(input.statementRate, card.currency),
  ];
  const calculation = calculateExpectedReward(
    {
      currency: card.currency,
      rewardUnit: card.rewardUnit,
      pointsPerCurrencyUnit: card.pointsPerCurrencyUnit,
      baseRatePercent: input.rates.baseRatePercent,
      rules: input.rates.rules,
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

  const missingRate = calculation.currencies.filter((c) => c.excludedCount > 0);
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
  if (input.requestedRate && foreignWithRate.length > 1) {
    warnings.push({
      code: 'EXCHANGE_RATE_APPLIED_TO_MULTIPLE_CURRENCIES',
      message: `The exchangeRate you sent was applied to several currencies (${foreignWithRate.map((c) => c.currency).join(', ')}).`,
    });
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
    reportedAmount,
    reportedLabel: program?.name ?? null,
    reportedSource,
    expectedAmount: calculation.expectedTotal,
    difference: comparison.difference,
    tolerance: comparison.tolerance,
    verdict: comparison.verdict,
    breakdown,
    transactions,
    conversion: {
      requestedRate: input.requestedRate,
      statementRate: input.statementRate,
      currencies: calculation.currencies,
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
