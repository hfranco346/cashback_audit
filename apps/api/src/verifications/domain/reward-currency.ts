import { Decimal } from 'decimal.js';
import { statementRatesToPrimary } from './exchange-rates.js';
import {
  REWARD_ELIGIBLE_KINDS,
  type StatementExchangeRate,
  type TransactionKind,
} from './statement.js';

/**
 * Currency the reward is denominated in: the card's explicit override, else
 * what the selected loyalty program says, else the card's primary currency.
 * Points and miles have no currency: null (no conversion applies).
 */
export function resolveRewardCurrency(input: {
  rewardUnit: 'CASHBACK_CURRENCY' | 'POINTS';
  cardRewardCurrency: string | null;
  programCurrency: string | null;
  primaryCurrency: string;
}): string | null {
  if (input.rewardUnit === 'POINTS') return null;
  return (
    input.cardRewardCurrency ?? input.programCurrency ?? input.primaryCurrency
  );
}

export interface RewardConversionProposal {
  /** Primary (card) currency. */
  fromCurrency: string;
  /** Reward currency. */
  toCurrency: string;
  /** Primary-currency units per 1 unit of the reward currency, or null. */
  rate: Decimal | null;
  source: 'STATEMENT' | 'NONE';
  /** True when no rate is known: the client must collect one. */
  required: boolean;
}

const sixDecimals = (value: Decimal) => value.toDecimalPlaces(6);

/** Null when the reward is in the primary currency (or has no currency). */
export function proposeRewardConversion(input: {
  primaryCurrency: string;
  rewardCurrency: string | null;
  printedRates: StatementExchangeRate[];
}): RewardConversionProposal | null {
  const { rewardCurrency, primaryCurrency } = input;
  if (!rewardCurrency || rewardCurrency === primaryCurrency) return null;
  const printed = statementRatesToPrimary(
    input.printedRates,
    primaryCurrency,
  ).find((r) => r.from === rewardCurrency);
  return {
    fromCurrency: primaryCurrency,
    toCurrency: rewardCurrency,
    rate: printed ? sixDecimals(printed.rate) : null,
    source: printed ? 'STATEMENT' : 'NONE',
    required: !printed,
  };
}

export interface SpendConversionProposal {
  currency: string;
  rate: Decimal | null;
  source: 'STATEMENT' | 'NONE';
  /** Always false: a missing rate only excludes that currency's lines. */
  required: false;
}

/** One entry per foreign currency present in reward-eligible lines. */
export function proposeSpendConversions(input: {
  primaryCurrency: string;
  lines: { currency: string; kind: TransactionKind }[];
  printedRates: StatementExchangeRate[];
}): SpendConversionProposal[] {
  const printed = new Map(
    statementRatesToPrimary(input.printedRates, input.primaryCurrency).map(
      (r) => [r.from, r.rate] as const,
    ),
  );
  const currencies = [
    ...new Set(
      input.lines
        .filter(
          (l) =>
            REWARD_ELIGIBLE_KINDS.includes(l.kind) &&
            l.currency !== input.primaryCurrency,
        )
        .map((l) => l.currency),
    ),
  ].sort();
  return currencies.map((currency) => {
    const rate = printed.get(currency);
    return {
      currency,
      rate: rate ? sixDecimals(rate) : null,
      source: rate ? ('STATEMENT' as const) : ('NONE' as const),
      required: false as const,
    };
  });
}
