import { Decimal } from 'decimal.js';

/**
 * ISO 4217 minor units (number of decimals) for the currencies that do not use
 * the common 2. This is the standard's data, not a bank or country rule; every
 * other code defaults to 2.
 */
const ZERO_DECIMAL = new Set([
  'BIF',
  'CLP',
  'DJF',
  'GNF',
  'ISK',
  'JPY',
  'KMF',
  'KRW',
  'PYG',
  'RWF',
  'UGX',
  'UYI',
  'VND',
  'VUV',
  'XAF',
  'XOF',
  'XPF',
]);
const THREE_DECIMAL = new Set([
  'BHD',
  'IQD',
  'JOD',
  'KWD',
  'LYD',
  'OMR',
  'TND',
]);

/** Decimals used to show and round amounts of `currency` (ISO 4217). */
export function currencyDecimals(currency: string | null | undefined): number {
  if (!currency) return 2;
  const code = currency.toUpperCase();
  if (ZERO_DECIMAL.has(code)) return 0;
  if (THREE_DECIMAL.has(code)) return 3;
  return 2;
}

/** Rounds a money amount to the minor units of its currency (half up). */
export function roundMoney(
  value: Decimal,
  currency: string | null | undefined,
): Decimal {
  return value.toDecimalPlaces(
    currencyDecimals(currency),
    Decimal.ROUND_HALF_UP,
  );
}
