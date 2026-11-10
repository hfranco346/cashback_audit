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
    exchangeRates: [],
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
    expect(result?.exchangeRates).toEqual([]);
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

describe('loyalty program reporting fields', () => {
  const row = (over: Record<string, unknown> = {}) => ({
    name: 'CASH PROGRAM',
    accumulated: '1,158',
    available: '1,100',
    redeemedInPeriod: '',
    expiring: '',
    forfeited: '',
    previousBalance: '1,000',
    earnedInPeriod: '',
    reportedLabel: ' Acumulado ',
    unit: 'CURRENCY',
    ...over,
  });

  it('reads the previous balance, earned figure and printed label', () => {
    const program = parseExtraction(
      baseOutput({ loyaltyPrograms: [row({ earnedInPeriod: '58' })] }),
    )!.loyaltyPrograms[0]!;
    expect(program.previousBalance?.toString()).toBe('1000');
    expect(program.earnedInPeriod?.toString()).toBe('58');
    expect(program.reportedLabel).toBe('Acumulado');
  });

  it('maps empty sentinels to null and tolerates older outputs', () => {
    const empty = parseExtraction(
      baseOutput({
        loyaltyPrograms: [row({ previousBalance: '', reportedLabel: '' })],
      }),
    )!.loyaltyPrograms[0]!;
    expect(empty.previousBalance).toBeNull();
    expect(empty.earnedInPeriod).toBeNull();
    expect(empty.reportedLabel).toBeNull();

    const { previousBalance, earnedInPeriod, reportedLabel, ...legacy } = row();
    void previousBalance;
    void earnedInPeriod;
    void reportedLabel;
    const old = parseExtraction(baseOutput({ loyaltyPrograms: [legacy] }))!
      .loyaltyPrograms[0]!;
    expect(old.previousBalance).toBeNull();
    expect(old.reportedLabel).toBeNull();
  });
});

describe('summary subtotals', () => {
  it('reads purchases and chargesAndInterest, "" meaning unknown', () => {
    const result = parseExtraction(
      baseOutput({
        summaries: [
          {
            currency: 'HNL',
            previousBalance: '',
            purchasesAndCharges: '',
            purchases: '22,242.56',
            chargesAndInterest: '725.16',
            totalBalance: '',
          },
          {
            currency: 'USD',
            previousBalance: '',
            purchasesAndCharges: '10',
            purchases: '',
            chargesAndInterest: '',
            totalBalance: '',
          },
        ],
      }),
    )!;
    expect(result.summaries[0]!.purchases!.toString()).toBe('22242.56');
    expect(result.summaries[0]!.chargesAndInterest!.toString()).toBe('725.16');
    expect(result.summaries[1]!.purchases).toBeNull();
  });
});

describe('requested output schema size', () => {
  it('stays free of nullable fields and anyOf (the API grammar limit)', async () => {
    const { zodOutputFormat } = await import('@anthropic-ai/sdk/helpers/zod');
    const { extractionOutputSchema } = await import('./extraction-schema.js');
    const json = JSON.stringify(zodOutputFormat(extractionOutputSchema));
    expect(json).not.toContain('anyOf');
    expect(json).not.toContain('oneOf');
    expect(json).not.toContain('"null"');
    expect(json).not.toContain('nullable');
  });
});
