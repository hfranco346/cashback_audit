import { Decimal } from 'decimal.js';
import type { RewardReportingSetting } from '../../cards/domain/card.js';
import { normalizeText } from './merchant-matcher.js';
import type { LoyaltyProgram } from './statement.js';

export type RewardReportingMode = 'MONTHLY' | 'CUMULATIVE';

/** Where the previous balance used for a CUMULATIVE audit came from. */
export type PreviousBalanceSource =
  'STATEMENT' | 'PREVIOUS_VERIFICATION' | 'USER' | 'PREVIOUS_STATEMENT';

export const PREVIOUS_BALANCE_SOURCES: readonly PreviousBalanceSource[] = [
  'USER',
  'PREVIOUS_STATEMENT',
  'STATEMENT',
  'PREVIOUS_VERIFICATION',
];

export type SuggestionReason =
  | 'STATEMENT_HAS_PREVIOUS_BALANCE'
  | 'CARD_SETTING'
  | 'LABEL_SAYS_ACCUMULATED'
  | 'REPORTED_FAR_ABOVE_EXPECTED'
  | 'NONE';

/** How the reward figure of a completed audit was derived. */
export interface VerificationRewardReporting {
  mode: RewardReportingMode;
  /** Program the figures belong to (matched by normalized name next month). */
  programName: string | null;
  /** Printed label of the audited figure ("Acumulado"), when known. */
  reportedLabel: string | null;
  /** Running balance printed this month; null when it was not used/known. */
  currentBalance: Decimal | null;
  previousBalance: Decimal | null;
  previousBalanceSource: PreviousBalanceSource | null;
  previousVerificationId: string | null;
  /** Period end (ISO date) of the previous audit when it was the source. */
  previousPeriodEnd: string | null;
  redeemedInPeriod: Decimal;
  expiredInPeriod: Decimal;
  /** Amount earned in the period; the figure the verdict used when CUMULATIVE. */
  earned: Decimal | null;
}

/** The previous balance found for a CUMULATIVE audit. */
export interface PreviousBalance {
  value: Decimal;
  source: PreviousBalanceSource;
  previousVerificationId: string | null;
  /** Period end of the previous audit (source PREVIOUS_VERIFICATION). */
  previousPeriodEnd?: string | null;
}

/** What the user chose in the confirm step. */
export interface RewardReportingChoice {
  mode: RewardReportingMode;
  previousBalance: Decimal | null;
  previousBalanceSource: PreviousBalanceSource | null;
  rememberForCard: boolean;
}

/** Label wordings that say the printed figure is a running balance. */
const ACCUMULATED_LABELS = [
  'acumulad',
  'saldo',
  'disponible',
  'balance',
  'accumulated',
  'available',
];

/** A reported figure above this multiple of the expected one looks cumulative. */
export const FAR_ABOVE_FACTOR = 3;
/** ...and only counts above this absolute amount (cashback currency / points). */
export const FAR_ABOVE_FLOOR_CURRENCY = new Decimal(10);
export const FAR_ABOVE_FLOOR_POINTS = new Decimal(500);

/** Days of tolerance between the previous periodEnd and this periodStart. */
export const PREVIOUS_PERIOD_TOLERANCE_DAYS = 5;

const zero = new Decimal(0);

/** The program's running balance: the accumulated column, else available. */
export function programBalance(program: LoyaltyProgram): Decimal | null {
  return program.accumulated ?? program.available ?? null;
}

/** Amount that left the balance through expiry/write-off during the period. */
export function expiredInPeriod(program: LoyaltyProgram): Decimal {
  return program.forfeited ?? zero;
}

/** earned = current - previous + redeemed + expired. */
export function deriveEarned(input: {
  currentBalance: Decimal;
  previousBalance: Decimal;
  redeemedInPeriod: Decimal;
  expiredInPeriod: Decimal;
}): Decimal {
  return input.currentBalance
    .minus(input.previousBalance)
    .plus(input.redeemedInPeriod)
    .plus(input.expiredInPeriod);
}

export function labelSaysAccumulated(label: string | null): boolean {
  if (!label) return false;
  const text = normalizeText(label);
  return ACCUMULATED_LABELS.some((w) => text.includes(w));
}

export function statementHasPreviousBalance(program: LoyaltyProgram): boolean {
  return program.previousBalance !== null || program.earnedInPeriod !== null;
}

export interface Suggestion {
  suggestedMode: RewardReportingMode;
  reason: SuggestionReason;
}

/**
 * Backend suggestion for the confirm question. An explicit card setting is the
 * user's own remembered answer and wins; then what the statement prints, the
 * wording of the printed label and, last, a reported figure far above what the
 * rates predict.
 */
export function suggestMode(input: {
  program: LoyaltyProgram | null;
  cardSetting: RewardReportingSetting;
  /** Expected reward in the reward unit, when it can be estimated. */
  expected: Decimal | null;
  rewardUnit: 'CASHBACK_CURRENCY' | 'POINTS';
}): Suggestion {
  if (input.cardSetting !== 'AUTO') {
    return { suggestedMode: input.cardSetting, reason: 'CARD_SETTING' };
  }
  const { program } = input;
  if (!program) return { suggestedMode: 'MONTHLY', reason: 'NONE' };
  if (statementHasPreviousBalance(program)) {
    return {
      suggestedMode: 'CUMULATIVE',
      reason: 'STATEMENT_HAS_PREVIOUS_BALANCE',
    };
  }
  if (labelSaysAccumulated(program.reportedLabel)) {
    return { suggestedMode: 'CUMULATIVE', reason: 'LABEL_SAYS_ACCUMULATED' };
  }
  const reported = program.accumulated;
  const floor =
    input.rewardUnit === 'POINTS'
      ? FAR_ABOVE_FLOOR_POINTS
      : FAR_ABOVE_FLOOR_CURRENCY;
  if (
    reported &&
    input.expected &&
    reported.gt(floor) &&
    reported.gt(input.expected.abs().mul(FAR_ABOVE_FACTOR))
  ) {
    return {
      suggestedMode: 'CUMULATIVE',
      reason: 'REPORTED_FAR_ABOVE_EXPECTED',
    };
  }
  return { suggestedMode: 'MONTHLY', reason: 'NONE' };
}

/** Equal normalized names, else a unique "contains" match. */
export function matchProgramName<T>(
  candidates: T[],
  nameOf: (candidate: T) => string,
  wanted: string,
): T | null {
  const needle = normalizeText(wanted);
  if (!needle) return null;
  const exact = candidates.filter((c) => normalizeText(nameOf(c)) === needle);
  if (exact.length >= 1) return exact[0]!;
  const partial = candidates.filter((c) => {
    const name = normalizeText(nameOf(c));
    return name.length >= 3 && (name.includes(needle) || needle.includes(name));
  });
  return partial.length === 1 ? partial[0]! : null;
}

/** Previous balance printed on the statement itself (decision B). */
export function previousFromStatement(
  program: LoyaltyProgram,
): PreviousBalance | null {
  return program.previousBalance
    ? {
        value: program.previousBalance,
        source: 'STATEMENT',
        previousVerificationId: null,
      }
    : null;
}

/** Whole days between two ISO dates (b - a). */
export function daysBetween(a: string, b: string): number {
  return Math.round(
    (Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000,
  );
}

/** ISO date shifted by whole days. */
export function shiftDate(date: string, days: number): string {
  const ms = Date.parse(`${date}T00:00:00Z`) + days * 86_400_000;
  return new Date(ms).toISOString().slice(0, 10);
}

/** What the confirm screen needs to ask "earned this month or accumulated?". */
export interface RewardReportingProposal {
  /** Mode to preselect: the stored one, the card's explicit setting or the suggestion. */
  mode: RewardReportingMode;
  suggestedMode: RewardReportingMode;
  reason: SuggestionReason;
  cardSetting: RewardReportingSetting;
  currentBalance: Decimal | null;
  previousBalance: Decimal | null;
  previousBalanceSource: PreviousBalanceSource | null;
  previousVerificationId: string | null;
  previousPeriodEnd: string | null;
  /** Program name as printed, and the printed label of its audited figure. */
  programName: string | null;
  reportedLabel: string | null;
  redeemedInPeriod: Decimal;
  expiredInPeriod: Decimal;
  earned: Decimal | null;
  /**
   * True when choosing CUMULATIVE would need the user to provide the previous
   * balance (the statement does not print it and no earlier audit has it).
   */
  previousBalanceRequired: boolean;
}
