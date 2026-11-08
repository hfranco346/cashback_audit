import { Decimal } from 'decimal.js';
import type { ConversionRate } from './reward-calculator.js';
import type { StatementExchangeRate } from './statement.js';

/**
 * Rate direction used everywhere in the API: a rate is "units of the PRIMARY
 * (card) currency per 1 unit of the other currency". Examples:
 * - primary HNL, other USD, rate "25.80": 1 USD = 25.80 HNL.
 * - primary CRC, other EUR, rate "560.00": 1 EUR = 560.00 CRC.
 */
export const MAX_RATE_DECIMALS = 6;

/** Rates usable to reach `primary`, from those printed on the statement. */
export function statementRatesToPrimary(
  printed: StatementExchangeRate[],
  primary: string,
): ConversionRate[] {
  const out: ConversionRate[] = [];
  const seen = new Set<string>();
  for (const p of printed) {
    if (p.rate.lte(0)) continue;
    let from: string | null = null;
    let rate: Decimal | null = null;
    if (p.to === primary && p.from !== primary) {
      from = p.from;
      rate = p.rate;
    } else if (p.from === primary && p.to !== primary) {
      from = p.to;
      rate = new Decimal(1).div(p.rate);
    }
    if (from && rate && !seen.has(from)) {
      seen.add(from);
      out.push({ from, rate, source: 'STATEMENT' });
    }
  }
  return out;
}
