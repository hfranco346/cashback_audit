import { describe, expect, it } from 'vitest';
import type { AuditFacts } from '../../domain/statement-extractor.js';
import {
  formatAmount,
  formatMoney,
  toExplainerInput,
} from './explainer-input.js';

const facts = (over: Partial<AuditFacts> = {}): AuditFacts => ({
  verdict: 'UNDERPAID',
  rewardUnit: 'CASHBACK_CURRENCY',
  primaryCurrency: 'HNL',
  rewardCurrency: 'HNL',
  expectedInPrimaryCurrency: null,
  reported: '1526.84',
  expected: '2100',
  difference: '-573.16',
  tolerance: '21',
  programName: 'CASH BAC',
  reportedSource: 'STATEMENT',
  breakdown: [
    {
      category: null,
      ratePercent: '1',
      spend: '210000',
      expectedReward: '2100',
      capped: false,
      monthlyCap: null,
    },
  ],
  excludedForeignLines: 0,
  warningCodes: ['NO_EXCHANGE_RATE', 'EXPLANATION_UNAVAILABLE'],
  ...over,
});

describe('toExplainerInput', () => {
  it.each([
    ['MATCH', 'coincide'],
    ['UNDERPAID', 'te pagaron de menos'],
    ['OVERPAID', 'te pagaron de más'],
  ] as const)('translates the verdict %s', (verdict, spanish) => {
    const text = JSON.stringify(toExplainerInput(facts({ verdict })));
    expect(text).toContain(spanish);
    for (const enumName of ['MATCH', 'UNDERPAID', 'OVERPAID']) {
      expect(text).not.toContain(enumName);
    }
  });

  it('sends no internal codes and formats money with currency and separators', () => {
    const text = JSON.stringify(toExplainerInput(facts()));
    expect(text).toContain('HNL 1,526.84');
    expect(text).toContain('HNL -573.16');
    expect(text).not.toMatch(
      /NO_EXCHANGE_RATE|EXPLANATION_UNAVAILABLE|CASHBACK_CURRENCY|STATEMENT/,
    );
  });

  it('states the card-currency figure when the reward was converted', () => {
    const input = toExplainerInput(
      facts({
        rewardCurrency: 'USD',
        expectedInPrimaryCurrency: '1360',
        reported: '2.6',
        expected: '2.62',
      }),
    );
    expect(input.reportadoPorElBanco).toBe('USD 2.60');
    expect(input.esperadoEnMonedaDeLaTarjeta).toBe('HNL 1,360.00');
  });

  it('formats points and zero-decimal currencies', () => {
    expect(formatMoney('1500', null)).toBe('1,500.00 puntos');
    expect(formatMoney('1234567', 'JPY')).toBe('JPY 1,234,567');
    expect(formatAmount('12', 'USD')).toBe('12.00');
  });
});
