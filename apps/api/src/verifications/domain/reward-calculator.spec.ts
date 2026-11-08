import { Decimal } from 'decimal.js';
import {
  calculateExpectedReward,
  compareReward,
  type ConversionRate,
  type RewardCardConfig,
  type RewardTransactionInput,
} from './reward-calculator.js';

const d = (v: string | number) => new Decimal(v);
const SUPER = 'cat-super';
const GAS = 'cat-gas';

const card = (over: Partial<RewardCardConfig> = {}): RewardCardConfig => ({
  currency: 'HNL',
  rewardUnit: 'CASHBACK_CURRENCY',
  pointsPerCurrencyUnit: d(1),
  baseRatePercent: d(1),
  rules: [
    { categoryId: SUPER, ratePercent: d(5), monthlyCap: null },
    { categoryId: GAS, ratePercent: d(3), monthlyCap: null },
  ],
  ...over,
});

let counter = 0;
const tx = (
  amount: string | number,
  categoryId: string | null = null,
  isCredit = false,
): RewardTransactionInput => ({
  index: counter++,
  amount: d(amount),
  currency: 'HNL',
  kind: isCredit ? 'REFUND' : 'PURCHASE',
  isCredit,
  categoryId,
});

const usd = (
  amount: string | number,
  categoryId: string | null = null,
  isCredit = false,
): RewardTransactionInput => ({
  ...tx(amount, categoryId, isCredit),
  currency: 'USD',
});

const requestRate = (rate: string): ConversionRate => ({
  from: null,
  rate: d(rate),
  source: 'REQUEST',
});
const statementRate = (from: string, rate: string): ConversionRate => ({
  from,
  rate: d(rate),
  source: 'STATEMENT',
});

describe('calculateExpectedReward', () => {
  beforeEach(() => {
    counter = 0;
  });

  it('returns zero for an empty statement', () => {
    const result = calculateExpectedReward(card(), []);
    expect(result.expectedTotal.toString()).toBe('0');
    expect(result.breakdown).toEqual([]);
    expect(result.transactions).toEqual([]);
  });

  it('applies only the base rate when nothing is categorized', () => {
    const result = calculateExpectedReward(card(), [tx(100), tx('250.50')]);
    expect(result.expectedTotal.toString()).toBe('3.51'); // 350.50 * 1% = 3.505 -> half up
    expect(result.breakdown).toHaveLength(1);
    expect(result.breakdown[0]).toMatchObject({
      categoryId: null,
      transactionCount: 2,
    });
    expect(result.transactions.every((t) => !t.ruleApplied)).toBe(true);
  });

  it('applies category rule rates and the base rate to the rest', () => {
    const result = calculateExpectedReward(card(), [
      tx(1000, SUPER), // 50
      tx(200, GAS), // 6
      tx(300), // 3 base
    ]);
    expect(result.expectedTotal.toString()).toBe('59');
    const byCat = Object.fromEntries(
      result.breakdown.map((b) => [String(b.categoryId), b]),
    );
    expect(byCat[SUPER]!.expectedReward.toString()).toBe('50');
    expect(byCat[GAS]!.expectedReward.toString()).toBe('6');
    expect(byCat['null']!.expectedReward.toString()).toBe('3');
    expect(
      result.breakdown[result.breakdown.length - 1]!.categoryId,
    ).toBeNull();
  });

  it('uses the base rate for a category the card has no rule for', () => {
    const result = calculateExpectedReward(card(), [tx(100, 'cat-unknown')]);
    expect(result.expectedTotal.toString()).toBe('1');
    expect(result.transactions[0]).toMatchObject({
      ruleApplied: false,
      categoryId: 'cat-unknown',
    });
    expect(result.transactions[0]!.appliedRatePercent.toString()).toBe('1');
  });

  it('subtracts refunds at the rate of their category', () => {
    const result = calculateExpectedReward(card(), [
      tx(1000, SUPER),
      tx(200, SUPER, true),
      tx(100),
      tx(50, null, true),
    ]);
    // super: 800 * 5% = 40 ; base: 50 * 1% = 0.5
    expect(result.expectedTotal.toString()).toBe('40.5');
    expect(
      result.breakdown.find((b) => b.categoryId === SUPER)!.spend.toString(),
    ).toBe('800');
    expect(result.transactions[1]!.expectedReward.toString()).toBe('-10');
  });

  it('caps a rule at its monthly cap and flags it', () => {
    const c = card({
      rules: [{ categoryId: SUPER, ratePercent: d(5), monthlyCap: d(30) }],
    });
    const result = calculateExpectedReward(c, [tx(1000, SUPER), tx(100)]);
    const line = result.breakdown.find((b) => b.categoryId === SUPER)!;
    expect(line).toMatchObject({ capped: true });
    expect(line.uncappedReward.toString()).toBe('50');
    expect(line.expectedReward.toString()).toBe('30');
    expect(result.expectedTotal.toString()).toBe('31'); // 30 capped + 1 base
  });

  it('does not flag a rule exactly at its cap or below it', () => {
    const c = card({
      rules: [{ categoryId: SUPER, ratePercent: d(5), monthlyCap: d(50) }],
    });
    const result = calculateExpectedReward(c, [tx(1000, SUPER)]);
    expect(result.breakdown[0]).toMatchObject({ capped: false });
    expect(result.expectedTotal.toString()).toBe('50');
  });

  it('applies the cap to the net of purchases and refunds', () => {
    const c = card({
      rules: [{ categoryId: SUPER, ratePercent: d(5), monthlyCap: d(30) }],
    });
    // gross 1000 -> 50, refund 500 -> -25 => net 25 < cap
    const result = calculateExpectedReward(c, [
      tx(1000, SUPER),
      tx(500, SUPER, true),
    ]);
    expect(result.breakdown[0]).toMatchObject({ capped: false });
    expect(result.expectedTotal.toString()).toBe('25');
  });

  it('caps each rule independently', () => {
    const c = card({
      rules: [
        { categoryId: SUPER, ratePercent: d(5), monthlyCap: d(10) },
        { categoryId: GAS, ratePercent: d(3), monthlyCap: d(5) },
      ],
    });
    const result = calculateExpectedReward(c, [tx(1000, SUPER), tx(1000, GAS)]);
    expect(result.expectedTotal.toString()).toBe('15');
  });

  describe('POINTS cards', () => {
    it('multiplies by points per currency unit', () => {
      const c = card({ rewardUnit: 'POINTS', pointsPerCurrencyUnit: d(10) });
      const result = calculateExpectedReward(c, [tx(1000, SUPER), tx(100)]);
      // 50 * 10 + 1 * 10
      expect(result.expectedTotal.toString()).toBe('510');
    });

    it('applies caps in points (after the multiplier)', () => {
      const c = card({
        rewardUnit: 'POINTS',
        pointsPerCurrencyUnit: d(2),
        rules: [{ categoryId: SUPER, ratePercent: d(5), monthlyCap: d(80) }],
      });
      const result = calculateExpectedReward(c, [tx(1000, SUPER)]); // 50 * 2 = 100 -> 80
      expect(result.expectedTotal.toString()).toBe('80');
      expect(result.breakdown[0]).toMatchObject({ capped: true });
    });

    it('ignores pointsPerCurrencyUnit for cashback cards', () => {
      const c = card({ pointsPerCurrencyUnit: d(10) });
      expect(
        calculateExpectedReward(c, [tx(100)]).expectedTotal.toString(),
      ).toBe('1');
    });
  });

  it('rounds to 2 decimals half-up without float error', () => {
    // 0.1 + 0.2 style trap: 3 * 3.33 * 1% = 0.0999 -> 0.1
    const result = calculateExpectedReward(
      card({ baseRatePercent: d('1.5') }),
      [tx('33.33'), tx('33.33'), tx('33.33')],
    );
    expect(result.expectedTotal.toString()).toBe('1.5'); // 99.99 * 1.5% = 1.49985
  });

  it('keeps the transaction category and index in the detail', () => {
    const result = calculateExpectedReward(card(), [tx(10, SUPER), tx(20)]);
    expect(
      result.transactions.map((t) => [t.index, t.categoryId, t.ruleApplied]),
    ).toEqual([
      [0, SUPER, true],
      [1, null, false],
    ]);
  });
});

describe('calculateExpectedReward - multi-currency and kinds', () => {
  beforeEach(() => {
    counter = 0;
  });

  it('converts foreign lines into the card currency before applying rates', () => {
    const result = calculateExpectedReward(
      card(),
      [tx(1000, SUPER), usd(10, SUPER), usd(20)],
      [statementRate('USD', '25')],
    );
    // super: 1000 + 10*25 = 1250 * 5% = 62.5 ; base: 20*25 = 500 * 1% = 5
    expect(result.expectedTotal.toString()).toBe('67.5');
    expect(result.transactions[1]).toMatchObject({
      excludedReason: null,
      rateSource: 'STATEMENT',
      ruleApplied: true,
    });
    expect(result.transactions[1]!.convertedAmount!.toString()).toBe('250');
    expect(result.transactions[1]!.exchangeRate!.toString()).toBe('25');
    expect(result.transactions[0]!.rateSource).toBeNull();
    expect(result.breakdown[0]!.spend.toString()).toBe('1250');
  });

  it('reports per-currency subtotals with the rate used', () => {
    const result = calculateExpectedReward(
      card(),
      [tx(1000, SUPER), usd(10, SUPER), usd(4, null, true)],
      [requestRate('25')],
    );
    const [hnl, us] = result.currencies;
    expect(hnl).toMatchObject({ currency: 'HNL', isPrimary: true });
    expect(hnl!.spent.toString()).toBe('1000');
    expect(hnl!.expectedReward.toString()).toBe('50');
    expect(us).toMatchObject({
      currency: 'USD',
      isPrimary: false,
      rateSource: 'REQUEST',
    });
    expect(us!.spent.toString()).toBe('6');
    expect(us!.convertedEligibleSpent.toString()).toBe('150');
    expect(us!.exchangeRate!.toString()).toBe('25');
    // 10*25*5% = 12.5 ; refund 4*25*1% = -1
    expect(us!.expectedReward.toString()).toBe('11.5');
  });

  it('prefers the first matching rate (request before statement)', () => {
    const result = calculateExpectedReward(
      card(),
      [usd(10)],
      [requestRate('30'), statementRate('USD', '25')],
    );
    expect(result.transactions[0]!.exchangeRate!.toString()).toBe('30');
    expect(result.transactions[0]!.rateSource).toBe('REQUEST');
  });

  it('matches a statement rate only to its own currency', () => {
    const eur: RewardTransactionInput = { ...tx(10), currency: 'EUR' };
    const result = calculateExpectedReward(
      card(),
      [usd(10), eur],
      [statementRate('USD', '25')],
    );
    expect(result.transactions[0]!.excludedReason).toBeNull();
    expect(result.transactions[1]!.excludedReason).toBe('NO_EXCHANGE_RATE');
  });

  it('excludes foreign lines without a rate instead of failing', () => {
    const result = calculateExpectedReward(card(), [
      tx(1000, SUPER),
      usd(10, SUPER),
    ]);
    expect(result.expectedTotal.toString()).toBe('50');
    expect(result.transactions[1]).toMatchObject({
      excludedReason: 'NO_EXCHANGE_RATE',
      convertedAmount: null,
      exchangeRate: null,
      expectedReward: d(0),
    });
    const us = result.currencies.find((c) => c.currency === 'USD')!;
    expect(us.excludedCount).toBe(1);
    expect(us.spent.toString()).toBe('10');
    expect(us.eligibleSpent.toString()).toBe('0');
    expect(us.exchangeRate).toBeNull();
    expect(result.breakdown.reduce((n, b) => n + b.transactionCount, 0)).toBe(
      1,
    );
  });

  it.each(['FEE', 'INTEREST', 'INSURANCE', 'PAYMENT', 'OTHER'] as const)(
    'excludes %s lines from the reward and the subtotals',
    (kind) => {
      const line: RewardTransactionInput = {
        ...tx(500, SUPER),
        kind,
        isCredit: kind === 'PAYMENT',
      };
      const result = calculateExpectedReward(card(), [tx(100), line]);
      expect(result.expectedTotal.toString()).toBe('1');
      expect(result.transactions[1]).toMatchObject({
        excludedReason: 'NON_PURCHASE_KIND',
        categoryId: null,
        ruleApplied: false,
      });
      expect(result.currencies[0]!.spent.toString()).toBe('100');
    },
  );

  it('does not create a subtotal for currencies that only have excluded kinds', () => {
    const fee: RewardTransactionInput = { ...usd(5), kind: 'FEE' };
    const result = calculateExpectedReward(card(), [tx(100), fee]);
    expect(result.currencies.map((c) => c.currency)).toEqual(['HNL']);
  });

  it('applies the monthly cap to the converted reward, across currencies', () => {
    const c = card({
      rules: [{ categoryId: SUPER, ratePercent: d(5), monthlyCap: d(60) }],
    });
    // 400 + 10 USD * 25 = 650 -> 32.5 ; + 20 USD * 25 = 500 -> 25 => 57.5 < 60
    const under = calculateExpectedReward(
      c,
      [tx(400, SUPER), usd(10, SUPER), usd(20, SUPER)],
      [requestRate('25')],
    );
    expect(under.breakdown[0]).toMatchObject({ capped: false });
    expect(under.expectedTotal.toString()).toBe('57.5');

    // 400 + 30 USD * 25 = 1150 -> 57.5 ; + 5 USD * 25 more = 1275 -> 63.75 > 60
    const over = calculateExpectedReward(
      c,
      [tx(400, SUPER), usd(30, SUPER), usd(5, SUPER)],
      [requestRate('25')],
    );
    expect(over.breakdown[0]).toMatchObject({ capped: true });
    expect(over.breakdown[0]!.uncappedReward.toString()).toBe('63.75');
    expect(over.expectedTotal.toString()).toBe('60');
    // per-currency subtotals stay uncapped
    expect(
      over.currencies
        .reduce((sum, x) => sum.plus(x.expectedReward), d(0))
        .toString(),
    ).toBe('63.75');
  });

  it('applies POINTS multiplier after conversion', () => {
    const c = card({ rewardUnit: 'POINTS', pointsPerCurrencyUnit: d(10) });
    const result = calculateExpectedReward(c, [usd(10)], [requestRate('25')]);
    // 250 * 1% * 10
    expect(result.expectedTotal.toString()).toBe('25');
  });

  it('subtracts converted refunds', () => {
    const result = calculateExpectedReward(
      card(),
      [usd(10, SUPER), usd(4, SUPER, true)],
      [requestRate('25')],
    );
    expect(result.expectedTotal.toString()).toBe('7.5'); // 6*25*5%
    expect(result.transactions[1]!.convertedAmount!.toString()).toBe('-100');
  });
});

describe('compareReward', () => {
  it('MATCH when equal', () => {
    expect(compareReward(d(100), d(100))).toMatchObject({ verdict: 'MATCH' });
  });

  it('uses a 1 unit tolerance for small rewards (boundary inclusive)', () => {
    expect(compareReward(d('9.00'), d('10.00'))).toMatchObject({
      verdict: 'MATCH',
    });
    expect(compareReward(d('8.99'), d('10.00'))).toMatchObject({
      verdict: 'UNDERPAID',
    });
    expect(compareReward(d('11.00'), d('10.00'))).toMatchObject({
      verdict: 'MATCH',
    });
    expect(compareReward(d('11.01'), d('10.00'))).toMatchObject({
      verdict: 'OVERPAID',
    });
  });

  it('uses 1% of expected once it exceeds 1 unit (boundary inclusive)', () => {
    // expected 1000 -> tolerance 10
    expect(compareReward(d(990), d(1000))).toMatchObject({ verdict: 'MATCH' });
    expect(compareReward(d('989.99'), d(1000))).toMatchObject({
      verdict: 'UNDERPAID',
    });
    expect(compareReward(d(1010), d(1000))).toMatchObject({ verdict: 'MATCH' });
    expect(compareReward(d('1010.01'), d(1000))).toMatchObject({
      verdict: 'OVERPAID',
    });
    expect(compareReward(d(990), d(1000)).tolerance.toString()).toBe('10');
  });

  it('reports the signed difference (reported - expected)', () => {
    expect(compareReward(d(80), d(100)).difference.toString()).toBe('-20');
    expect(compareReward(d(130), d(100)).difference.toString()).toBe('30');
  });

  it('handles zero expected rewards (empty statement)', () => {
    expect(compareReward(d(0), d(0))).toMatchObject({ verdict: 'MATCH' });
    expect(compareReward(d(5), d(0))).toMatchObject({ verdict: 'OVERPAID' });
  });

  it('handles negative expected rewards using the absolute value', () => {
    expect(compareReward(d(-100), d(-100))).toMatchObject({ verdict: 'MATCH' });
    expect(compareReward(d(0), d(-1000))).toMatchObject({
      verdict: 'OVERPAID',
    });
  });
});
