import { describe, expect, it } from 'vitest';
import { normalizeNumber, parseExtraction } from './extraction-schema.js';

function baseOutput(overrides: Record<string, unknown> = {}) {
  return {
    isCreditCardStatement: true,
    bank: 'Example Bank',
    cardLast4: '',
    periodStart: '2026-10-03',
    periodEnd: '2026-11-03',
    currency: 'HNL',
    summaries: [
      {
        currency: 'HNL',
        previousBalance: '',
        purchasesAndCharges: '1,234.50',
        totalBalance: '',
      },
    ],
    exchangeRate: { from: '', to: '', rate: '' },
    loyaltyPrograms: [],
    detectedRates: [],
    transactions: [],
    ...overrides,
  };
}

describe('normalizeNumber', () => {
  it.each([
    ['8,942', '8942'],
    ['1,234.50', '1234.50'],
    ['12,345,678.9', '12345678.9'],
    ['1.234,50', '1234.50'],
    ['6534', '6534'],
    ['0', '0'],
  ])('normalizes %s to %s', (input, expected) => {
    expect(normalizeNumber(input)).toBe(expected);
  });

  it.each(['6,5', '1,23', '12,34.5'])(
    'leaves ambiguous %s unchanged',
    (input) => {
      expect(normalizeNumber(input)).toBe(input);
    },
  );
});

describe('parseExtraction', () => {
  it('maps empty-string sentinels to null', () => {
    const result = parseExtraction(baseOutput());
    expect(result?.cardLast4).toBeNull();
    expect(result?.exchangeRate).toBeNull();
    expect(result?.summaries[0]?.previousBalance).toBeNull();
    expect(result?.summaries[0]?.purchasesAndCharges?.toString()).toBe(
      '1234.5',
    );
  });

  it('keeps loyalty balances printed with thousands separators', () => {
    const result = parseExtraction(
      baseOutput({
        loyaltyPrograms: [
          {
            name: 'CASH PROGRAM',
            accumulated: '0',
            available: '6,534',
            redeemedInPeriod: '0',
            expiring: '0',
            forfeited: '',
            unit: 'CURRENCY',
          },
        ],
      }),
    );
    const program = result?.loyaltyPrograms[0];
    expect(program?.accumulated?.toString()).toBe('0');
    expect(program?.available?.toString()).toBe('6534');
    expect(program?.forfeited).toBeNull();
  });

  it('accepts transaction amounts with thousands separators', () => {
    const result = parseExtraction(
      baseOutput({
        transactions: [
          {
            date: '2026-10-05',
            reference: '',
            description: 'PAYMENT RECEIVED',
            amount: '68,531.56',
            currency: 'HNL',
            isCredit: true,
            kind: 'PAYMENT',
          },
        ],
      }),
    );
    expect(result?.transactions[0]?.amount.toString()).toBe('68531.56');
    expect(result?.transactions[0]?.reference).toBeNull();
  });
});
