import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import { computeAudit, type AuditInput } from './audit.js';
import type { LoyaltyProgram } from './statement.js';
import type { VerificationTransaction } from './verification.js';

const d = (v: string | number) => new Decimal(v);

const tx = (
  index: number,
  amount: number,
  currency: string,
  over: Partial<VerificationTransaction> = {},
): VerificationTransaction => ({
  index,
  date: '2026-01-02',
  reference: null,
  merchant: `SHOP ${index}`,
  amount: d(amount),
  currency,
  isCredit: false,
  kind: 'PURCHASE',
  convertedAmount: null,
  exchangeRate: null,
  rateSource: null,
  excludedReason: null,
  matchedMerchantId: null,
  matchedMerchantName: null,
  categoryId: null,
  categoryName: null,
  matchSource: 'NONE',
  matchConfidence: null,
  matchReason: null,
  suggestedHint: null,
  appliedRatePercent: null,
  ruleApplied: false,
  expectedReward: null,
  ...over,
});

const prog = (
  accumulated: string,
  over: Partial<LoyaltyProgram> = {},
): LoyaltyProgram => ({
  name: 'CASH BACK',
  accumulated: d(accumulated),
  available: null,
  redeemedInPeriod: null,
  expiring: null,
  forfeited: null,
  unit: 'CURRENCY',
  currency: null,
  ...over,
});

const input = (over: Partial<AuditInput> = {}): AuditInput => ({
  card: {
    currency: 'HNL',
    rewardUnit: 'CASHBACK_CURRENCY',
    pointsPerCurrencyUnit: d(1),
    rewardCurrency: null,
  },
  rates: { baseRatePercent: d(7), rules: [] },
  transactions: [tx(0, 25800, 'HNL')],
  categoryNames: new Map(),
  programs: [prog('70', { currency: 'USD' })],
  requestedProgramName: null,
  cardProgramName: null,
  reportedOverride: null,
  requestedRate: null,
  requestedRates: {},
  requestedRewardRate: null,
  statementRates: [],
  ...over,
});

const printed = (from: string, to: string, rate: string) => ({
  from,
  to,
  rate: d(rate),
  source: 'STATEMENT' as const,
});

describe('computeAudit: reward currency', () => {
  it('converts an HNL-computed reward into the USD program currency', () => {
    // 25,800 HNL * 7% = 1,806 HNL -> / 25.80 = 70 USD
    const audit = computeAudit(input({ requestedRewardRate: d('25.80') }));
    expect(audit.rewardCurrency).toBe('USD');
    expect(audit.expectedInPrimary.toString()).toBe('1806');
    expect(audit.expectedAmount.toString()).toBe('70');
    expect(audit.reportedAmount.toString()).toBe('70');
    expect(audit.verdict).toBe('MATCH');
    expect(audit.rewardExchangeRate).toMatchObject({
      fromCurrency: 'HNL',
      toCurrency: 'USD',
      source: 'USER_ENTERED',
    });
    expect(audit.conversion.reward!.expectedInPrimary.toString()).toBe('1806');
  });

  it('rounds only at the end, to the reward currency decimals', () => {
    // 1,000 HNL * 7% = 70 HNL / 24.65 = 2.8397... USD -> 2.84
    const audit = computeAudit(
      input({
        transactions: [tx(0, 1000, 'HNL')],
        requestedRewardRate: d('24.65'),
        reportedOverride: d('2.84'),
      }),
    );
    expect(audit.expectedAmount.toString()).toBe('2.84');
    expect(audit.difference.toString()).toBe('0');
  });

  it('judges the verdict in the reward currency', () => {
    const under = computeAudit(
      input({ requestedRewardRate: d('25.80'), reportedOverride: d('60') }),
    );
    expect(under.verdict).toBe('UNDERPAID');
    expect(under.difference.toString()).toBe('-10');
    expect(under.tolerance.toString()).toBe('1');
  });

  it('requires a rate when none is known', () => {
    expect(() => computeAudit(input())).toThrowError(
      expect.objectContaining({ code: 'REWARD_EXCHANGE_RATE_REQUIRED' }),
    );
  });

  it('uses the statement-printed pair in either direction', () => {
    const direct = computeAudit(
      input({ statementRates: [printed('USD', 'HNL', '25.80')] }),
    );
    expect(direct.rewardExchangeRate).toMatchObject({
      source: 'STATEMENT_CONFIRMED',
    });
    expect(direct.expectedAmount.toString()).toBe('70');
    const inverse = computeAudit(
      input({ statementRates: [printed('HNL', 'USD', '0.0387596899')] }),
    );
    expect(inverse.expectedAmount.toFixed(0)).toBe('70');
  });

  it('prefers the explicit rate over the statement and marks echoes as confirmed', () => {
    const stmt = [printed('USD', 'HNL', '25')];
    const own = computeAudit(
      input({ statementRates: stmt, requestedRewardRate: d('25.80') }),
    );
    expect(own.rewardExchangeRate).toMatchObject({
      rate: d('25.80'),
      source: 'USER_ENTERED',
    });
    const echo = computeAudit(
      input({ statementRates: stmt, requestedRewardRate: d('25') }),
    );
    expect(echo.rewardExchangeRate!.source).toBe('STATEMENT_CONFIRMED');
  });

  it('the card override wins over the program currency', () => {
    const audit = computeAudit(
      input({
        card: {
          currency: 'HNL',
          rewardUnit: 'CASHBACK_CURRENCY',
          pointsPerCurrencyUnit: d(1),
          rewardCurrency: 'EUR',
        },
        requestedRewardRate: d('28'),
        reportedOverride: d('64.5'),
      }),
    );
    expect(audit.rewardCurrency).toBe('EUR');
    expect(audit.expectedAmount.toString()).toBe('64.5');
  });

  it('falls back to the primary currency without conversion', () => {
    const audit = computeAudit(input({ programs: [prog('1806')] }));
    expect(audit.rewardCurrency).toBe('HNL');
    expect(audit.rewardExchangeRate).toBeNull();
    expect(audit.conversion.reward).toBeNull();
    expect(audit.expectedAmount.toString()).toBe('1806');
  });

  it('is unaffected for points programs, whatever currency is around', () => {
    const audit = computeAudit(
      input({
        card: {
          currency: 'HNL',
          rewardUnit: 'POINTS',
          pointsPerCurrencyUnit: d(1),
          rewardCurrency: 'USD',
        },
        programs: [prog('1806', { unit: 'POINTS', currency: 'USD' })],
      }),
    );
    expect(audit.rewardCurrency).toBeNull();
    expect(audit.rewardExchangeRate).toBeNull();
    expect(audit.expectedAmount.toString()).toBe('1806');
  });

  it('rounds zero-decimal reward currencies to whole units', () => {
    // 1,000 CRC * 5% = 50 CRC; reward in JPY at 0.05 CRC per JPY -> 1000 JPY
    const audit = computeAudit(
      input({
        card: {
          currency: 'CRC',
          rewardUnit: 'CASHBACK_CURRENCY',
          pointsPerCurrencyUnit: d(1),
          rewardCurrency: 'JPY',
        },
        rates: { baseRatePercent: d(5), rules: [] },
        transactions: [tx(0, 1000, 'CRC')],
        programs: [prog('10')],
        requestedRewardRate: d('3.33'),
      }),
    );
    // 50 / 3.33 = 15.015 -> 15 JPY (no decimals)
    expect(audit.expectedAmount.toString()).toBe('15');
    expect(audit.difference.toString()).toBe('-5');
  });
});

describe('computeAudit: several foreign currencies', () => {
  const lines = [tx(0, 56000, 'CRC'), tx(1, 100, 'USD'), tx(2, 50, 'EUR')];
  const crc = (over: Partial<AuditInput> = {}) =>
    input({
      card: {
        currency: 'CRC',
        rewardUnit: 'CASHBACK_CURRENCY',
        pointsPerCurrencyUnit: d(1),
        rewardCurrency: null,
      },
      rates: { baseRatePercent: d(1), rules: [] },
      transactions: lines,
      programs: [prog('1', { currency: 'USD' })],
      ...over,
    });

  it('converts each currency with its own rate and the reward to USD', () => {
    // 56,000 + 100*520 + 50*560 = 136,000 CRC * 1% = 1,360 CRC = 2.615.. USD
    const audit = crc({
      requestedRates: { USD: d('520'), EUR: d('560') },
    });
    const result = computeAudit(audit);
    expect(result.expectedInPrimary.toString()).toBe('1360');
    // the USD reward reuses the USD spend rate (520): 1360 / 520 = 2.615 -> 2.62
    expect(result.rewardExchangeRate).toMatchObject({
      rate: d('520'),
      toCurrency: 'USD',
    });
    expect(result.expectedAmount.toString()).toBe('2.62');
    expect(result.transactions.map((t) => [t.currency, t.rateSource])).toEqual([
      ['CRC', null],
      ['USD', 'REQUEST'],
      ['EUR', 'REQUEST'],
    ]);
  });

  it('excludes only the currency whose rate is missing', () => {
    const result = computeAudit(crc({ requestedRates: { USD: d('520') } }));
    expect(result.transactions[2]).toMatchObject({
      currency: 'EUR',
      excludedReason: 'NO_EXCHANGE_RATE',
    });
    expect(result.transactions[1]!.excludedReason).toBeNull();
    expect(result.expectedInPrimary.toString()).toBe('1080');
    const warning = result.warnings.find((w) => w.code === 'NO_EXCHANGE_RATE');
    expect(warning?.message).toContain('EUR');
    expect(warning?.message).not.toContain('USD,');
  });

  it('takes statement-printed rates for several pairs', () => {
    const result = computeAudit(
      crc({
        statementRates: [
          printed('USD', 'CRC', '520'),
          printed('CRC', 'EUR', '0.001785714'),
        ],
      }),
    );
    expect(result.transactions[1]!.rateSource).toBe('STATEMENT');
    expect(result.transactions[2]!.rateSource).toBe('STATEMENT');
    expect(result.transactions[2]!.excludedReason).toBeNull();
  });
});
