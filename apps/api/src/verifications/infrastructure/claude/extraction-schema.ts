import { Decimal } from 'decimal.js';
import { z } from 'zod';
import type { ExtractedStatement } from '../../domain/statement.js';
import { ExtractionFailedError } from '../../domain/verification-errors.js';

/**
 * Shape requested from Claude (structured outputs). Kept deliberately simple
 * because the JSON-schema subset the API enforces is limited; the strict checks
 * live in `parseExtraction` below.
 */
export const extractionOutputSchema = z.object({
  isCreditCardStatement: z
    .boolean()
    .describe(
      'False when the document is not a readable credit card statement',
    ),
  bank: z.string().nullable().describe('Issuing bank name'),
  cardLast4: z
    .string()
    .nullable()
    .describe('Last four digits of the card number if printed'),
  periodStart: z
    .string()
    .nullable()
    .describe('Statement period start, YYYY-MM-DD'),
  periodEnd: z
    .string()
    .nullable()
    .describe('Statement period end (closing date), YYYY-MM-DD'),
  currency: z
    .string()
    .nullable()
    .describe('ISO 4217 currency code of the statement'),
  totalSpent: z
    .string()
    .nullable()
    .describe(
      'Total purchases of the period as a plain decimal string, e.g. "12345.67"',
    ),
  totalToPay: z
    .string()
    .nullable()
    .describe('Total balance to pay as a plain decimal string'),
  reportedReward: z
    .object({
      amount: z
        .string()
        .describe('Reward EARNED in this period as a plain decimal string'),
      unit: z.enum(['POINTS', 'CURRENCY']),
      label: z
        .string()
        .describe('Name printed on the statement, e.g. "Puntos ganados"'),
    })
    .nullable(),
  transactions: z.array(
    z.object({
      date: z.string().describe('YYYY-MM-DD'),
      merchant: z.string().describe('Merchant text exactly as printed'),
      amount: z.string().describe('Positive plain decimal string'),
      isCredit: z
        .boolean()
        .describe('True for refunds, returns, reversals and merchant credits'),
    }),
  ),
});

export type ExtractionOutput = z.infer<typeof extractionOutputSchema>;

const DECIMAL = /^\d{1,13}(\.\d{1,6})?$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY = /^[A-Z]{3}$/;
const MAX_TRANSACTIONS = 2000;

const decimal = z.string().trim().regex(DECIMAL);
const optionalDecimal = z
  .string()
  .nullable()
  .transform((value) =>
    value && DECIMAL.test(value.trim()) ? new Decimal(value.trim()) : null,
  );
const optionalDate = z
  .string()
  .nullable()
  .transform((value) =>
    value && ISO_DATE.test(value.trim()) ? value.trim() : null,
  );

const strictSchema = extractionOutputSchema.extend({
  cardLast4: z
    .string()
    .nullable()
    .transform((value) => {
      const digits = value?.replace(/\D/g, '') ?? '';
      return digits.length >= 4 ? digits.slice(-4) : null;
    }),
  periodStart: optionalDate,
  periodEnd: optionalDate,
  currency: z
    .string()
    .nullable()
    .transform((value) =>
      value && CURRENCY.test(value.trim().toUpperCase())
        ? value.trim().toUpperCase()
        : null,
    ),
  totalSpent: optionalDecimal,
  totalToPay: optionalDecimal,
  reportedReward: z
    .object({
      amount: decimal,
      unit: z.enum(['POINTS', 'CURRENCY']),
      label: z.string().max(200),
    })
    .nullable()
    .catch(null),
  transactions: z
    .array(
      z.object({
        date: z.string().trim().regex(ISO_DATE),
        merchant: z.string().trim().min(1).max(300),
        amount: decimal,
        isCredit: z.boolean(),
      }),
    )
    .max(MAX_TRANSACTIONS),
});

/**
 * Validates the model output at runtime. A readable-but-not-a-statement result
 * is returned as `null`; malformed data throws ExtractionFailedError because
 * silently dropping transactions would corrupt the audit.
 */
export function parseExtraction(raw: unknown): ExtractedStatement | null {
  const result = strictSchema.safeParse(raw);
  if (!result.success) throw new ExtractionFailedError();
  const data = result.data;
  if (!data.isCreditCardStatement) return null;
  return {
    bank: data.bank?.trim() || null,
    cardLast4: data.cardLast4,
    periodStart: data.periodStart,
    periodEnd: data.periodEnd,
    currency: data.currency,
    totalSpent: data.totalSpent,
    totalToPay: data.totalToPay,
    reportedReward: data.reportedReward
      ? {
          amount: new Decimal(data.reportedReward.amount),
          unit: data.reportedReward.unit,
          label: data.reportedReward.label.trim(),
        }
      : null,
    transactions: data.transactions.map((t) => ({
      date: t.date,
      merchant: t.merchant,
      amount: new Decimal(t.amount),
      isCredit: t.isCredit,
    })),
  };
}

export const classificationOutputSchema = z.object({
  matches: z.array(
    z.object({
      descriptor: z.string(),
      merchantId: z.string().nullable(),
      confidence: z.number(),
    }),
  ),
});
