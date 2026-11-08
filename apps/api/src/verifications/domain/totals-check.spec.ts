import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import type { CurrencySummary, ExtractedTransaction } from './statement.js';
import { checkStatementTotals } from './totals-check.js';

const d = (v: string | number) => new Decimal(v);
const line = (
  amount: string,
  over: Partial<ExtractedTransaction> = {},
): ExtractedTransaction => ({
  date: '2026-01-02',
  reference: null,
  merchant: 'X',
  amount: d(amount),
  currency: 'HNL',
  isCredit: false,
  kind: 'PURCHASE',
  ...over,
});
const summary = (over: Partial<CurrencySummary> = {}): CurrencySummary => ({
  currency: 'HNL',
  previousBalance: null,
  purchasesAndCharges: null,
  purchases: null,
  chargesAndInterest: null,
  totalBalance: null,
  ...over,
});

// Banco Ficohsa-like numbers: purchases 22,242.56 + charges/interest 725.16.
const ficohsaLines = [
  line('20000'),
  line('2242.56'),
  line('300', { kind: 'REFUND', isCredit: true }),
  line('300'),
  line('600.16', { kind: 'INTEREST' }),
  line('125', { kind: 'FEE' }),
  line('5000', { kind: 'PAYMENT', isCredit: true }),
];

describe('checkStatementTotals', () => {
  it('does not warn when purchases match the purchases subtotal', () => {
    expect(
      checkStatementTotals(
        summary({
          purchases: d('22242.56'),
          chargesAndInterest: d('725.16'),
          purchasesAndCharges: d('22967.72'),
        }),
        ficohsaLines,
      ),
    ).toBeNull();
  });

  it('does not compare against purchases-and-charges when purchases is present', () => {
    // Lines (purchases only) equal `purchases`; the combined figure is not used.
    expect(
      checkStatementTotals(
        summary({ purchases: d('22242.56'), purchasesAndCharges: d('999999') }),
        ficohsaLines,
      ),
    ).toBeNull();
  });

  it('warns accurately when purchases do not match', () => {
    const warning = checkStatementTotals(
      summary({ purchases: d('30000') }),
      ficohsaLines,
    );
    expect(warning?.code).toBe('TOTAL_SPENT_MISMATCH');
    expect(warning?.message).toContain('22242.56');
    expect(warning?.message).toContain('30000.00');
    expect(warning?.message).toContain('in purchases');
  });

  it('applies max(1, 0.5%) as tolerance', () => {
    // 0.5% of 22,242.56 = 111.21
    const lines = [line('22140')];
    expect(
      checkStatementTotals(summary({ purchases: d('22242.56') }), lines),
    ).toBeNull();
    expect(
      checkStatementTotals(summary({ purchases: d('22300') }), lines),
    ).not.toBeNull();
    expect(
      checkStatementTotals(summary({ purchases: d('100') }), [line('100.9')]),
    ).toBeNull();
  });

  it('falls back to purchases + charges (either reading) without a subtotal', () => {
    const base = summary({ purchasesAndCharges: d('22967.72') });
    expect(checkStatementTotals(base, ficohsaLines)).toBeNull();
    expect(
      checkStatementTotals(
        summary({ purchasesAndCharges: d('22242.56') }),
        ficohsaLines,
      ),
    ).toBeNull();
    const warning = checkStatementTotals(
      summary({ purchasesAndCharges: d('50000') }),
      ficohsaLines,
    );
    expect(warning?.message).toContain('including fees, interest');
  });

  it('ignores currencies without lines or figures', () => {
    expect(checkStatementTotals(summary(), ficohsaLines)).toBeNull();
    expect(
      checkStatementTotals(
        summary({ currency: 'USD', purchases: d(0) }),
        ficohsaLines,
      ),
    ).toBeNull();
  });
});
