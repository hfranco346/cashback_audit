import { Decimal } from 'decimal.js';

export type CalculatorRewardUnit = 'CASHBACK_CURRENCY' | 'POINTS';

export interface RewardRuleConfig {
  categoryId: string;
  ratePercent: Decimal;
  /** Max reward from the rule per statement period, in reward units. */
  monthlyCap: Decimal | null;
}

export interface RewardCardConfig {
  rewardUnit: CalculatorRewardUnit;
  pointsPerCurrencyUnit: Decimal;
  baseRatePercent: Decimal;
  rules: RewardRuleConfig[];
}

export interface RewardTransactionInput {
  /** Position in the statement; echoed back in the detail. */
  index: number;
  /** Positive magnitude. */
  amount: Decimal;
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
  expectedTotal: Decimal;
  breakdown: BreakdownLine[];
  transactions: TransactionReward[];
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

/** Pure computation of the reward a card should have earned. */
export function calculateExpectedReward(
  card: RewardCardConfig,
  transactions: RewardTransactionInput[],
): RewardCalculation {
  const multiplier =
    card.rewardUnit === 'POINTS' ? card.pointsPerCurrencyUnit : new Decimal(1);
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

  for (const tx of transactions) {
    const rule = tx.categoryId
      ? (rulesByCategory.get(tx.categoryId) ?? null)
      : null;
    const ratePercent = rule ? rule.ratePercent : card.baseRatePercent;
    const signed = tx.isCredit ? tx.amount.neg() : tx.amount;
    const reward = signed.mul(ratePercent).div(100).mul(multiplier);

    const key = rule ? rule.categoryId : null;
    const group = groups.get(key) ?? {
      rule,
      ratePercent,
      count: 0,
      spend: new Decimal(0),
      reward: new Decimal(0),
    };
    group.count += 1;
    group.spend = group.spend.plus(signed);
    group.reward = group.reward.plus(reward);
    groups.set(key, group);

    details.push({
      index: tx.index,
      categoryId: tx.categoryId,
      appliedRatePercent: ratePercent,
      ruleApplied: rule !== null,
      expectedReward: round2(reward),
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
      spend: round2(group.spend),
      uncappedReward: round2(group.reward),
      expectedReward: round2(applied),
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

  return { expectedTotal: round2(total), breakdown, transactions: details };
}

/**
 * Compares the reward reported by the bank with the expected one. The
 * tolerance is max(1 unit, 1% of the expected reward); the boundary counts
 * as a match.
 */
export function compareReward(
  reported: Decimal,
  expected: Decimal,
): RewardComparison {
  const difference = round2(reported.minus(expected));
  const tolerance = Decimal.max(new Decimal(1), expected.abs().mul('0.01'));
  let verdict: Verdict = 'MATCH';
  if (difference.abs().gt(tolerance)) {
    verdict = difference.isNegative() ? 'UNDERPAID' : 'OVERPAID';
  }
  return { verdict, difference, tolerance: round2(tolerance) };
}
