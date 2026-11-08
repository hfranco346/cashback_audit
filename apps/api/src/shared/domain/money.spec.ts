import { Decimal } from 'decimal.js';
import { describe, expect, it } from 'vitest';
import { currencyDecimals, roundMoney } from './money.js';

describe('money', () => {
  it.each([
    ['JPY', 0],
    ['clp', 0],
    ['KWD', 3],
    ['USD', 2],
    ['HNL', 2],
    [null, 2],
  ])('uses the ISO minor units of %s', (code, decimals) => {
    expect(currencyDecimals(code)).toBe(decimals);
  });

  it('rounds half up to the currency minor units', () => {
    expect(roundMoney(new Decimal('1234.5'), 'JPY').toString()).toBe('1235');
    expect(roundMoney(new Decimal('2.005'), 'USD').toString()).toBe('2.01');
    expect(roundMoney(new Decimal('1.00049'), 'KWD').toString()).toBe('1');
    expect(roundMoney(new Decimal('1.0005'), 'KWD').toString()).toBe('1.001');
  });
});
