import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import {
  proposeRewardConversion,
  proposeSpendConversions,
  resolveRewardCurrency,
} from './reward-currency.js';

const d = (v: string) => new Decimal(v);
const printed = (from: string, to: string, rate: string) => ({
  from,
  to,
  rate: d(rate),
  source: 'STATEMENT' as const,
});

describe('resolveRewardCurrency', () => {
  const base = {
    rewardUnit: 'CASHBACK_CURRENCY' as const,
    cardRewardCurrency: null,
    programCurrency: null,
    primaryCurrency: 'CRC',
  };
  it('card override > program > primary', () => {
    expect(
      resolveRewardCurrency({
        ...base,
        cardRewardCurrency: 'EUR',
        programCurrency: 'USD',
      }),
    ).toBe('EUR');
    expect(resolveRewardCurrency({ ...base, programCurrency: 'USD' })).toBe(
      'USD',
    );
    expect(resolveRewardCurrency(base)).toBe('CRC');
  });
  it('has no currency for points', () => {
    expect(
      resolveRewardCurrency({
        ...base,
        rewardUnit: 'POINTS',
        cardRewardCurrency: 'USD',
      }),
    ).toBeNull();
  });
});

describe('proposeRewardConversion', () => {
  it('is null without conversion', () => {
    expect(
      proposeRewardConversion({
        primaryCurrency: 'HNL',
        rewardCurrency: 'HNL',
        printedRates: [],
      }),
    ).toBeNull();
    expect(
      proposeRewardConversion({
        primaryCurrency: 'HNL',
        rewardCurrency: null,
        printedRates: [],
      }),
    ).toBeNull();
  });
  it('is required without a printed rate and prefilled with one', () => {
    expect(
      proposeRewardConversion({
        primaryCurrency: 'HNL',
        rewardCurrency: 'USD',
        printedRates: [],
      }),
    ).toMatchObject({ rate: null, source: 'NONE', required: true });
    expect(
      proposeRewardConversion({
        primaryCurrency: 'HNL',
        rewardCurrency: 'USD',
        printedRates: [printed('USD', 'HNL', '25.8')],
      }),
    ).toMatchObject({
      fromCurrency: 'HNL',
      toCurrency: 'USD',
      source: 'STATEMENT',
      required: false,
    });
  });
});

describe('proposeSpendConversions', () => {
  it('lists one entry per foreign currency of eligible lines', () => {
    const result = proposeSpendConversions({
      primaryCurrency: 'CRC',
      lines: [
        { currency: 'CRC', kind: 'PURCHASE' },
        { currency: 'USD', kind: 'PURCHASE' },
        { currency: 'EUR', kind: 'REFUND' },
        { currency: 'MXN', kind: 'FEE' },
      ],
      printedRates: [printed('USD', 'CRC', '520')],
    });
    expect(result.map((r) => [r.currency, r.source, r.required])).toEqual([
      ['EUR', 'NONE', false],
      ['USD', 'STATEMENT', false],
    ]);
  });
});
