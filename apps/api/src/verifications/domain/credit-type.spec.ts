import { describe, expect, it } from 'vitest';
import { creditTypeOf, TRANSACTION_KINDS } from './statement.js';

describe('creditTypeOf', () => {
  it('never labels a payment as a refund', () => {
    expect(creditTypeOf('PAYMENT', true)).toBe('PAYMENT');
  });
  it('labels returns as refunds', () => {
    expect(creditTypeOf('REFUND', true)).toBe('REFUND');
    expect(creditTypeOf('PURCHASE', true)).toBe('REFUND');
  });
  it('labels bonuses, adjustments and fee reversals as other credits', () => {
    for (const kind of ['OTHER', 'FEE', 'INTEREST', 'INSURANCE'] as const) {
      expect(creditTypeOf(kind, true)).toBe('OTHER_CREDIT');
    }
  });
  it('is null for charges', () => {
    for (const kind of TRANSACTION_KINDS) {
      expect(creditTypeOf(kind, false)).toBeNull();
    }
  });
});
