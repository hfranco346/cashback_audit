import { Decimal } from 'decimal.js';
import { z } from 'zod';
import {
  TRANSACTION_KINDS,
  type ExtractedStatement,
} from '../../domain/statement.js';
import { ExtractionFailedError } from '../../domain/verification-errors.js';

const LOYALTY_UNITS = ['POINTS', 'CURRENCY', 'MILES', 'UNKNOWN'] as const;

/**
 * Shape requested from Claude (structured outputs). Kept deliberately simple
 * because the API compiles the schema into a grammar with a size limit: no
 * nullable fields (each one becomes an `anyOf`). Unknown values are requested
 * as empty strings and normalized to null by `parseExtraction`, where the
 * strict checks live.
 */
export const extractionOutputSchema = z.object({
  isCreditCardStatement: z
    .boolean()
    .describe(
      'False when the document is not a readable credit card statement',
    ),
  bank: z.string().describe('Issuing bank name'),
  cardLast4: z
    .string()
    .describe('Last four digits of the card number if printed'),
  periodStart: z.string().describe('Statement period start, YYYY-MM-DD'),
  periodEnd: z
    .string()
    .describe('Statement period end (closing date), YYYY-MM-DD'),
  currency: z
    .string()
    .describe(
      'ISO 4217 code of the statement main (local) currency, null if unclear',
    ),
  summaries: z
    .array(
      z.object({
        currency: z.string().describe('ISO 4217 code of this summary column'),
        previousBalance: z
          .string()
          .describe('Balance carried over from the previous statement'),
        purchasesAndCharges: z
          .string()
          .describe('Purchases plus other charges of the period'),
        totalBalance: z.string().describe('Total balance owed / total to pay'),
      }),
    )
    .describe('One entry per currency column of the statement summary'),
  exchangeRates: z
    .array(
      z.object({
        from: z.string().describe('ISO 4217 code converted from'),
        to: z.string().describe('ISO 4217 code converted to'),
        rate: z.string().describe('1 unit of `from` in `to`, plain decimal'),
      }),
    )
    .describe(
      'Every exchange rate explicitly printed on the statement; empty if none',
    ),
  loyaltyPrograms: z
    .array(
      z.object({
        name: z.string().describe('Program name exactly as printed'),
        accumulated: z
          .string()
          .describe('Accumulated / earned column, as printed'),
        available: z.string().describe('Available / redeemable balance'),
        redeemedInPeriod: z
          .string()
          .describe('Redeemed / used during the period'),
        expiring: z.string().describe('Expiring soon'),
        forfeited: z.string().describe('Forfeited / expired / written off'),
        unit: z.enum(LOYALTY_UNITS),
        currency: z
          .string()
          .describe(
            'ISO 4217 code the reward is denominated in (cashback); empty for points/miles or if unclear',
          ),
      }),
    )
    .describe('Every row of any rewards/loyalty table; empty if none'),
  detectedRates: z
    .array(
      z.object({
        scope: z.enum(['BASE', 'CATEGORY']),
        categoryHint: z
          .string()
          .describe('Spending category as worded in the document'),
        suggestedCategoryId: z
          .string()
          .describe('Id of the matching category from the provided list'),
        ratePercent: z
          .string()
          .describe('Percent of spend as a plain decimal, e.g. "7"'),
        unitNote: z
          .string()
          .describe('Original wording when not a plain percentage'),
        evidence: z.string().describe('Short quote from the document'),
        confidence: z.number().describe('0 to 1'),
      }),
    )
    .describe(
      'Reward rates the document itself states; empty if it states none',
    ),
  transactions: z.array(
    z.object({
      date: z.string().describe('YYYY-MM-DD'),
      reference: z
        .string()
        .describe('Reference / authorization number if printed'),
      description: z.string().describe('Concept text exactly as printed'),
      amount: z.string().describe('Positive plain decimal string'),
      currency: z
        .string()
        .describe('ISO 4217 code of the column the amount is printed in'),
      isCredit: z
        .boolean()
        .describe(
          'True for refunds, returns, reversals, payments and other credits',
        ),
      kind: z.enum(TRANSACTION_KINDS),
    }),
  ),
});

export type ExtractionOutput = z.infer<typeof extractionOutputSchema>;

const DECIMAL = /^\d{1,13}(\.\d{1,6})?$/;
const RATE_DECIMAL = /^\d{1,3}(\.\d{1,4})?$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const CURRENCY = /^[A-Z]{3}$/;
const MAX_TRANSACTIONS = 2000;
const MAX_PROGRAMS = 20;
const MAX_DETECTED_RATES = 40;
const MAX_EXCHANGE_RATES = 20;

/**
 * Removes thousands separators only when the grouping is unambiguous
 * ("8,942", "1,234.50", "1.234,50"). Anything else is returned unchanged and
 * left to the DECIMAL check, so a lone "6,5" is never guessed.
 */
export function normalizeNumber(raw: string): string {
  const value = raw.trim();
  if (/^\d{1,3}(,\d{3})+(\.\d+)?$/.test(value)) return value.replace(/,/g, '');
  if (/^\d{1,3}(\.\d{3})+,\d+$/.test(value)) {
    return value.replace(/\./g, '').replace(',', '.');
  }
  return value;
}

const decimal = z
  .string()
  .trim()
  .transform(normalizeNumber)
  .pipe(z.string().regex(DECIMAL));
const optionalDecimal = z
  .string()
  .nullable()
  .transform((value) => {
    const normalized = value ? normalizeNumber(value) : null;
    return normalized && DECIMAL.test(normalized)
      ? new Decimal(normalized)
      : null;
  });
const optionalDate = z
  .string()
  .nullable()
  .transform((value) =>
    value && ISO_DATE.test(value.trim()) ? value.trim() : null,
  );
const currencyCode = z
  .string()
  .trim()
  .transform((v) => v.toUpperCase())
  .pipe(z.string().regex(CURRENCY));
const optionalCurrency = z
  .string()
  .nullable()
  .transform((value) =>
    value && CURRENCY.test(value.trim().toUpperCase())
      ? value.trim().toUpperCase()
      : null,
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
  currency: optionalCurrency,
  summaries: z
    .array(
      z.object({
        currency: optionalCurrency,
        previousBalance: optionalDecimal,
        purchasesAndCharges: optionalDecimal,
        totalBalance: optionalDecimal,
      }),
    )
    .max(10),
  exchangeRates: z
    .array(
      z.object({
        from: optionalCurrency,
        to: optionalCurrency,
        rate: z.string().nullable(),
      }),
    )
    .max(MAX_EXCHANGE_RATES)
    .catch([]),
  /** Legacy single-rate shape; still accepted from older stubs/outputs. */
  exchangeRate: z
    .object({
      from: optionalCurrency,
      to: optionalCurrency,
      rate: z.string().nullable(),
    })
    .nullable()
    .optional()
    .catch(null),
  loyaltyPrograms: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(120),
        accumulated: optionalDecimal,
        available: optionalDecimal,
        redeemedInPeriod: optionalDecimal,
        expiring: optionalDecimal,
        forfeited: optionalDecimal,
        unit: z.enum(LOYALTY_UNITS).catch('UNKNOWN'),
        currency: optionalCurrency.optional().catch(null),
      }),
    )
    .max(MAX_PROGRAMS)
    .catch([]),
  detectedRates: z
    .array(
      z.object({
        scope: z.enum(['BASE', 'CATEGORY']),
        categoryHint: z.string().nullable(),
        suggestedCategoryId: z.string().nullable(),
        ratePercent: z.string().nullable(),
        unitNote: z.string().nullable(),
        evidence: z.string(),
        confidence: z.number(),
      }),
    )
    .max(MAX_DETECTED_RATES)
    .catch([]),
  transactions: z
    .array(
      z.object({
        date: z.string().trim().regex(ISO_DATE),
        reference: z
          .string()
          .nullable()
          .transform((v) => v?.trim().slice(0, 60) || null),
        description: z.string().trim().min(1).max(300),
        amount: decimal,
        currency: z.string(),
        isCredit: z.boolean(),
        kind: z.enum(TRANSACTION_KINDS),
      }),
    )
    .max(MAX_TRANSACTIONS),
});

/** Recursively maps "" (the "unknown" sentinel requested from the model) to null. */
function emptyStringsToNull(value: unknown): unknown {
  if (typeof value === 'string') return value.trim() === '' ? null : value;
  if (Array.isArray(value)) return value.map(emptyStringsToNull);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([k, v]) => [k, emptyStringsToNull(v)]),
    );
  }
  return value;
}

/**
 * Validates the model output at runtime. A readable-but-not-a-statement result
 * is returned as `null`; malformed data throws ExtractionFailedError because
 * silently dropping transactions would corrupt the audit.
 *
 * A line whose currency is unreadable falls back to the statement currency;
 * if that is unknown too the extraction is unusable.
 */
export function parseExtraction(
  raw: unknown,
  validCategoryIds: ReadonlySet<string> = new Set(),
): ExtractedStatement | null {
  const result = strictSchema.safeParse(emptyStringsToNull(raw));
  if (!result.success) throw new ExtractionFailedError();
  const data = result.data;
  if (!data.isCreditCardStatement) return null;

  const summaries = data.summaries.flatMap((s) =>
    s.currency
      ? [
          {
            currency: s.currency,
            previousBalance: s.previousBalance,
            purchasesAndCharges: s.purchasesAndCharges,
            totalBalance: s.totalBalance,
          },
        ]
      : [],
  );
  const fallbackCurrency = data.currency ?? summaries[0]?.currency ?? null;

  const transactions = data.transactions.map((t) => {
    const parsed = currencyCode.safeParse(t.currency);
    const currency = parsed.success ? parsed.data : fallbackCurrency;
    if (!currency) throw new ExtractionFailedError();
    return {
      date: t.date,
      reference: t.reference,
      merchant: t.description,
      amount: new Decimal(t.amount),
      currency,
      isCredit: t.isCredit,
      kind: t.kind,
    };
  });

  const exchangeRates: ExtractedStatement['exchangeRates'] = [];
  for (const rate of [
    ...data.exchangeRates,
    ...(data.exchangeRate ? [data.exchangeRate] : []),
  ]) {
    const text = rate.rate ? normalizeNumber(rate.rate) : '';
    if (!rate.from || !rate.to || rate.from === rate.to || !DECIMAL.test(text))
      continue;
    const value = new Decimal(text);
    if (value.lte(0)) continue;
    if (exchangeRates.some((r) => r.from === rate.from && r.to === rate.to))
      continue;
    exchangeRates.push({
      from: rate.from,
      to: rate.to,
      rate: value,
      source: 'STATEMENT',
    });
  }

  return {
    bank: data.bank?.trim() || null,
    cardLast4: data.cardLast4,
    periodStart: data.periodStart,
    periodEnd: data.periodEnd,
    currency: fallbackCurrency,
    summaries,
    exchangeRates,
    loyaltyPrograms: data.loyaltyPrograms.map((p) => ({
      ...p,
      currency:
        p.unit === 'CURRENCY' || p.unit === 'UNKNOWN'
          ? (p.currency ?? null)
          : null,
    })),
    detectedRates: data.detectedRates.map((r) => {
      const percent =
        r.ratePercent && RATE_DECIMAL.test(r.ratePercent.trim())
          ? new Decimal(r.ratePercent.trim())
          : null;
      return {
        scope: r.scope,
        categoryHint: r.categoryHint?.trim().slice(0, 120) || null,
        suggestedCategoryId:
          r.scope === 'CATEGORY' &&
          r.suggestedCategoryId &&
          validCategoryIds.has(r.suggestedCategoryId)
            ? r.suggestedCategoryId
            : null,
        ratePercent: percent && percent.lte(100) ? percent : null,
        unitNote: r.unitNote?.trim().slice(0, 160) || null,
        evidence: r.evidence.trim().slice(0, 240),
        confidence: Math.min(
          1,
          Math.max(0, Number.isFinite(r.confidence) ? r.confidence : 0),
        ),
      };
    }),
    transactions,
  };
}

/** Shape requested from the classifier; ids are re-validated by the caller. */
export const classificationOutputSchema = z.object({
  matches: z.array(
    z.object({
      descriptor: z.string().describe('The descriptor, copied unchanged'),
      categoryId: z
        .string()
        .nullable()
        .describe('Id of the best category, or null when unsure'),
      matchedMerchantId: z
        .string()
        .nullable()
        .describe(
          'Id of a listed merchant only if it is clearly that merchant',
        ),
      confidence: z.number().describe('0 to 1'),
      reason: z.string().describe('At most 12 words'),
    }),
  ),
});
