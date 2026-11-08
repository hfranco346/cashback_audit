import { Decimal } from 'decimal.js';
import { currencyDecimals } from '../../shared/domain/money.js';
import type { CurrencySummary, ExtractedTransaction } from './statement.js';
import type { VerificationWarning } from './verification.js';

/** Tolerance: max(1 unit, 0.5% of the statement figure). */
const tolerance = (reference: Decimal) =>
  Decimal.max(1, reference.abs().mul('0.005'));

const signed = (
  lines: ExtractedTransaction[],
  kinds: readonly ExtractedTransaction['kind'][],
) =>
  lines
    .filter((t) => kinds.includes(t.kind))
    .reduce(
      (sum, t) => (t.isCredit ? sum.minus(t.amount) : sum.plus(t.amount)),
      new Decimal(0),
    );

const show = (value: Decimal, currency: string) =>
  value.toFixed(currencyDecimals(currency), Decimal.ROUND_HALF_UP);

/**
 * Compares the extracted lines of one currency with the statement summary.
 * - With the statement's `purchases` subtotal: purchases + refunds are compared
 *   against it (fees, interest and insurance are not part of that figure).
 * - Without it (older/unclear layouts): the "purchases + other charges" figure
 *   may match either the purchases alone or the lines including fees,
 *   interest, insurance and other charges.
 * Returns a warning only when the lines do not match; never throws.
 */
export function checkStatementTotals(
  summary: CurrencySummary,
  transactions: ExtractedTransaction[],
): VerificationWarning | null {
  const lines = transactions.filter((t) => t.currency === summary.currency);
  const purchasesOnly = signed(lines, ['PURCHASE', 'REFUND']);
  const cur = summary.currency;

  if (summary.purchases) {
    if (
      purchasesOnly
        .minus(summary.purchases)
        .abs()
        .lte(tolerance(summary.purchases))
    ) {
      return null;
    }
    return {
      code: 'TOTAL_SPENT_MISMATCH',
      message: `The extracted ${cur} purchases and refunds add up to ${show(purchasesOnly, cur)} but the statement reports ${show(summary.purchases, cur)} in purchases. Some transactions may be missing.`,
    };
  }

  const target = summary.purchasesAndCharges;
  if (!target) return null;
  const withCharges = signed(lines, [
    'PURCHASE',
    'REFUND',
    'FEE',
    'INTEREST',
    'INSURANCE',
    'OTHER',
  ]);
  const limit = tolerance(target);
  if (
    purchasesOnly.minus(target).abs().lte(limit) ||
    withCharges.minus(target).abs().lte(limit)
  ) {
    return null;
  }
  return {
    code: 'TOTAL_SPENT_MISMATCH',
    message: `The extracted ${cur} lines add up to ${show(purchasesOnly, cur)} in purchases (${show(withCharges, cur)} including fees, interest and other charges) but the statement reports ${show(target, cur)} in purchases plus charges. Some transactions may be missing.`,
  };
}
