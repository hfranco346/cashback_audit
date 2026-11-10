import { Decimal } from 'decimal.js';
import { roundMoney } from '../../shared/domain/money.js';
import { REWARD_ELIGIBLE_KINDS, type TransactionKind } from './statement.js';

export type CalculatorRewardUnit = 'CASHBACK_CURRENCY' | 'POINTS';

export interface RewardRuleConfig {
  categoryId: string;
  ratePercent: Decimal;
  /** Max reward from the rule per statement period, in reward units. */
  monthlyCap: Decimal | null;
}

export interface RewardCardConfig {
  /** Primary currency (ISO 4217): rates, caps and rewards are expressed in it. */
  currency: string;
  rewardUnit: CalculatorRewardUnit;
  pointsPerCurrencyUnit: Decimal;
  baseRatePercent: Decimal;
  rules: RewardRuleConfig[];
  /**
   * Max reward per statement for the whole card, in the same units as the
   * per-rule caps. Applied to the total after the per-rule caps; null = none.
   */
  rewardCap?: Decimal | null;
}

/** Card-wide cap that reduced the expected reward. */
export interface RewardCapApplied {
  cap: Decimal;
  /** Expected total before the card cap (after per-rule caps). */
  uncapped: Decimal;
  /** Expected total after the card cap (== cap). */
  capped: Decimal;
}

/** Conversion factor into the card currency: 1 `from` = `rate` card units. */
export interface ConversionRate {
  /** Currency it applies to; null = any foreign currency. */
  from: string | null;
  rate: Decimal;
  source: 'REQUEST' | 'STATEMENT';
}

export type ExcludedReason = 'NO_EXCHANGE_RATE' | 'NON_PURCHASE_KIND';

export interface RewardTransactionInput {
  /** Position in the statement; echoed back in the detail. */
  index: number;
  /** Positive magnitude, in `currency`. */
  amount: Decimal;
  /** ISO 4217 code of `amount`. */
  currency: string;
  /** Only PURCHASE and REFUND earn rewards. */
  kind: TransactionKind;
  /** Refunds / credits subtract from spend and reward. */
  isCredit: boolean;
  /** Category of the matched merchant, if any. */
  categoryId: string | null;
}

export interface TransactionReward {
  index: number;
  categoryId: string | null;
  appliedRatePercent: Decimal;
  /** True when a card rule (not the base rate) set the rate. */
  ruleApplied: boolean;
  /** Reward before monthly caps, rounded to 2 decimals. Negative for refunds. */
  expectedReward: Decimal;
  /** Signed amount in the card currency; null when it could not be converted. */
  convertedAmount: Decimal | null;
  /** Factor used (1 for the card currency); null when none applied. */
  exchangeRate: Decimal | null;
  rateSource: 'REQUEST' | 'STATEMENT' | null;
  /** Set when the line took no part in the calculation. */
  excludedReason: ExcludedReason | null;
}

/** Totals for one currency of the statement. */
export interface CurrencySubtotal {
  currency: string;
  isPrimary: boolean;
  /** Net purchases minus refunds of eligible kinds, in this currency. */
  spent: Decimal;
  /** Part of `spent` that was used in the calculation. */
  eligibleSpent: Decimal;
  /** `eligibleSpent` converted to the card currency. */
  convertedEligibleSpent: Decimal;
  exchangeRate: Decimal | null;
  rateSource: 'REQUEST' | 'STATEMENT' | null;
  /** Sum of the line rewards of this currency, before monthly caps. */
  expectedReward: Decimal;
  /** Eligible lines left out of the calculation (no exchange rate). */
  excludedCount: number;
}

export interface BreakdownLine {
  /** Category of the rule, or null for spend earning the base rate. */
  categoryId: string | null;
  ratePercent: Decimal;
  transactionCount: number;
  /** Net spend (purchases minus refunds). */
  spend: Decimal;
  /** Reward before the cap. */
  uncappedReward: Decimal;
  /** Reward after the cap. */
  expectedReward: Decimal;
  monthlyCap: Decimal | null;
  capped: boolean;
}

export interface RewardCalculation {
  /** In the card (primary) currency, rounded to its minor units. */
  expectedTotal: Decimal;
  /** Same figure before rounding (input to the reward-currency conversion). */
  expectedTotalExact: Decimal;
  /** Set only when the card-wide cap reduced the total; null otherwise. */
  rewardCapApplied: RewardCapApplied | null;
  breakdown: BreakdownLine[];
  transactions: TransactionReward[];
  currencies: CurrencySubtotal[];
}

export type Verdict = 'MATCH' | 'UNDERPAID' | 'OVERPAID';

export interface RewardComparison {
  verdict: Verdict;
  /** reported - expected; negative means the bank paid less than expected. */
  difference: Decimal;
  tolerance: Decimal;
}

const round2 = (value: Decimal) =>
  value.toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

/**
 * Converts a reward computed in the primary currency to the reward currency.
 * `rate` is primary-currency units per 1 reward-currency unit (e.g. 25.80 HNL
 * per USD). Rounded to the reward currency minor units, only at the end.
 */
export function convertRewardToCurrency(
  amountInPrimary: Decimal,
  rate: Decimal,
  rewardCurrency: string,
): Decimal {
  return roundMoney(amountInPrimary.div(rate), rewardCurrency);
}

/**
 * Pure computation of the reward a card should have earned.
 *
 * NOTE: every figure of the audit (conversion, rates, caps, totals,
 * comparison) is computed here, deterministically, with exact decimals. LLMs
 * only extract and classify text; they never do arithmetic.
 *
 * Foreign-currency lines are converted with the first matching entry of
 * `rates` (callers order it: request rate before statement rate). A line
 * without a usable rate is excluded (`NO_EXCHANGE_RATE`), not guessed.
 */
export function calculateExpectedReward(
  card: RewardCardConfig,
  transactions: RewardTransactionInput[],
  rates: ConversionRate[] = [],
): RewardCalculation {
  const multiplier =
    card.rewardUnit === 'POINTS' ? card.pointsPerCurrencyUnit : new Decimal(1);
  // Amounts in the card currency round to its minor units; rewards too unless
  // they are points (2 decimals).
  const roundPrimary = (v: Decimal) => roundMoney(v, card.currency);
  const roundReward = (v: Decimal) =>
    card.rewardUnit === 'POINTS' ? round2(v) : roundPrimary(v);
  const rulesByCategory = new Map(
    card.rules.map((rule) => [rule.categoryId, rule]),
  );

  interface Group {
    rule: RewardRuleConfig | null;
    ratePercent: Decimal;
    count: number;
    spend: Decimal;
    reward: Decimal;
  }
  const groups = new Map<string | null, Group>();
  const details: TransactionReward[] = [];

  const subtotals = new Map<string, CurrencySubtotal>();
  const subtotalFor = (currency: string) => {
    let sub = subtotals.get(currency);
    if (!sub) {
      sub = {
        currency,
        isPrimary: currency === card.currency,
        spent: new Decimal(0),
        eligibleSpent: new Decimal(0),
        convertedEligibleSpent: new Decimal(0),
        exchangeRate: null,
        rateSource: null,
        expectedReward: new Decimal(0),
        excludedCount: 0,
      };
      subtotals.set(currency, sub);
    }
    return sub;
  };
  const rateFor = (currency: string): ConversionRate | null => {
    if (currency === card.currency) {
      return { from: currency, rate: new Decimal(1), source: 'STATEMENT' };
    }
    return rates.find((r) => r.from === currency || r.from === null) ?? null;
  };

  for (const tx of transactions) {
    const signed = tx.isCredit ? tx.amount.neg() : tx.amount;
    const eligibleKind = REWARD_ELIGIBLE_KINDS.includes(tx.kind);
    const excluded = (
      reason: ExcludedReason,
      rate: ConversionRate | null,
    ): TransactionReward => ({
      index: tx.index,
      categoryId: null,
      appliedRatePercent: new Decimal(0),
      ruleApplied: false,
      expectedReward: new Decimal(0),
      convertedAmount: rate ? roundPrimary(signed.mul(rate.rate)) : null,
      exchangeRate: rate?.rate ?? null,
      rateSource: rate && tx.currency !== card.currency ? rate.source : null,
      excludedReason: reason,
    });

    if (!eligibleKind) {
      details.push(excluded('NON_PURCHASE_KIND', null));
      continue;
    }
    const sub = subtotalFor(tx.currency);
    sub.spent = sub.spent.plus(signed);

    const rate = rateFor(tx.currency);
    if (!rate) {
      sub.excludedCount += 1;
      details.push(excluded('NO_EXCHANGE_RATE', null));
      continue;
    }
    if (tx.currency !== card.currency) {
      sub.exchangeRate = rate.rate;
      sub.rateSource = rate.source;
    }
    const converted = signed.mul(rate.rate);

    const rule = tx.categoryId
      ? (rulesByCategory.get(tx.categoryId) ?? null)
      : null;
    const ratePercent = rule ? rule.ratePercent : card.baseRatePercent;
    const reward = converted.mul(ratePercent).div(100).mul(multiplier);

    sub.eligibleSpent = sub.eligibleSpent.plus(signed);
    sub.convertedEligibleSpent = sub.convertedEligibleSpent.plus(converted);
    sub.expectedReward = sub.expectedReward.plus(reward);

    const key = rule ? rule.categoryId : null;
    const group = groups.get(key) ?? {
      rule,
      ratePercent,
      count: 0,
      spend: new Decimal(0),
      reward: new Decimal(0),
    };
    group.count += 1;
    group.spend = group.spend.plus(converted);
    group.reward = group.reward.plus(reward);
    groups.set(key, group);

    details.push({
      index: tx.index,
      categoryId: tx.categoryId,
      appliedRatePercent: ratePercent,
      ruleApplied: rule !== null,
      expectedReward: roundReward(reward),
      convertedAmount: roundPrimary(converted),
      exchangeRate: rate.rate,
      rateSource: tx.currency === card.currency ? null : rate.source,
      excludedReason: null,
    });
  }

  let total = new Decimal(0);
  const breakdown: BreakdownLine[] = [];
  for (const [categoryId, group] of groups) {
    const cap = group.rule?.monthlyCap ?? null;
    const capped = cap !== null && group.reward.gt(cap);
    const applied = capped && cap ? cap : group.reward;
    total = total.plus(applied);
    breakdown.push({
      categoryId,
      ratePercent: group.ratePercent,
      transactionCount: group.count,
      spend: roundPrimary(group.spend),
      uncappedReward: roundReward(group.reward),
      expectedReward: roundReward(applied),
      monthlyCap: cap,
      capped,
    });
  }
  // Rule groups first (highest reward first), base-rate spend last.
  breakdown.sort((a, b) => {
    if ((a.categoryId === null) !== (b.categoryId === null))
      return a.categoryId === null ? 1 : -1;
    return b.expectedReward.comparedTo(a.expectedReward);
  });

  // Card-wide cap: after summing every category (per-rule caps included).
  let rewardCapApplied: RewardCapApplied | null = null;
  const cardCap = card.rewardCap ?? null;
  if (cardCap && total.gt(cardCap)) {
    rewardCapApplied = {
      cap: roundReward(cardCap),
      uncapped: roundReward(total),
      capped: roundReward(cardCap),
    };
    total = cardCap;
  }

  const currencies = [...subtotals.values()]
    .map((sub) => ({
      ...sub,
      spent: roundMoney(sub.spent, sub.currency),
      eligibleSpent: roundMoney(sub.eligibleSpent, sub.currency),
      convertedEligibleSpent: roundPrimary(sub.convertedEligibleSpent),
      expectedReward: roundReward(sub.expectedReward),
    }))
    .sort((a, b) => Number(b.isPrimary) - Number(a.isPrimary));

  return {
    expectedTotal: roundReward(total),
    expectedTotalExact: total,
    rewardCapApplied,
    breakdown,
    transactions: details,
    currencies,
  };
}

/**
 * Compares the reward reported by the bank with the expected one. The
 * tolerance is max(1 unit, 1% of the expected reward); the boundary counts
 * as a match.
 */
export function compareReward(
  reported: Decimal,
  expected: Decimal,
  /** Reward currency (minor units used for rounding); null for points. */
  currency: string | null = null,
): RewardComparison {
  const round = (v: Decimal) => roundMoney(v, currency);
  const difference = round(reported.minus(expected));
  const tolerance = Decimal.max(new Decimal(1), expected.abs().mul('0.01'));
  let verdict: Verdict = 'MATCH';
  if (difference.abs().gt(tolerance)) {
    verdict = difference.isNegative() ? 'UNDERPAID' : 'OVERPAID';
  }
  return { verdict, difference, tolerance: round(tolerance) };
}
