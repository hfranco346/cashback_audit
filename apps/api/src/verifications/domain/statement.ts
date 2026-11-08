import type { Decimal } from 'decimal.js';

/**
 * What a statement line is. Only PURCHASE and REFUND take part in the reward
 * calculation; everything else is shown but excluded.
 */
export const TRANSACTION_KINDS = [
  'PURCHASE',
  'FEE',
  'INTEREST',
  'INSURANCE',
  'PAYMENT',
  'REFUND',
  'OTHER',
] as const;
export type TransactionKind = (typeof TRANSACTION_KINDS)[number];

export const REWARD_ELIGIBLE_KINDS: readonly TransactionKind[] = [
  'PURCHASE',
  'REFUND',
];

/** Result of reading a statement PDF. Amounts are exact decimals. */
export interface ExtractedTransaction {
  /** ISO date `YYYY-MM-DD`. */
  date: string;
  /** Bank reference number (`No. de referencia`), when printed. */
  reference: string | null;
  /** Merchant text as printed on the statement. */
  merchant: string;
  /** Always positive; `isCredit` says whether it reduces the balance spent. */
  amount: Decimal;
  /** ISO 4217 code of the amount as printed (e.g. HNL, USD). */
  currency: string;
  /** Refund / reversal / payment / merchant credit. */
  isCredit: boolean;
  kind: TransactionKind;
}

/** Statement summary figures for one currency column. */
export interface CurrencySummary {
  currency: string;
  previousBalance: Decimal | null;
  /** "Compras + otros cargos". */
  purchasesAndCharges: Decimal | null;
  /** Purchases / withdrawals subtotal only (no fees, interest, insurance). */
  purchases: Decimal | null;
  /** Fees, interest and other charges subtotal. */
  chargesAndInterest: Decimal | null;
  /** "Saldo total" / total to pay. */
  totalBalance: Decimal | null;
}

/** Exchange rate printed on the statement: 1 `from` = `rate` `to`. */
export interface StatementExchangeRate {
  from: string;
  to: string;
  rate: Decimal;
  source: 'STATEMENT';
}

export type LoyaltyUnit = 'POINTS' | 'CURRENCY' | 'MILES' | 'UNKNOWN';

/** One row of the loyalty-program table of the statement. */
export interface LoyaltyProgram {
  name: string;
  /** "Acumulados" - may be a running balance rather than earned this period. */
  accumulated: Decimal | null;
  /** "Disponibles". */
  available: Decimal | null;
  /** "Redimidos en el mes". */
  redeemedInPeriod: Decimal | null;
  /** "Por vencer". */
  expiring: Decimal | null;
  /** "Castigados". */
  forfeited: Decimal | null;
  unit: LoyaltyUnit;
  /**
   * ISO 4217 code the reward is denominated in, when the statement shows it
   * (cashback programs); null for points/miles or when unknown.
   */
  currency: string | null;
}

/** A reward rate the statement itself states (promotion, program terms). */
export interface DetectedRate {
  scope: 'BASE' | 'CATEGORY';
  /** Category wording as written on the statement. */
  categoryHint: string | null;
  /** One of the user's categories, when the hint clearly maps to it. */
  suggestedCategoryId: string | null;
  /** Percent of spend; null when it cannot be expressed as a percentage. */
  ratePercent: Decimal | null;
  /** The raw wording when the rate is not a plain percentage. */
  unitNote: string | null;
  /** Short quote from the document. */
  evidence: string;
  /** 0..1 */
  confidence: number;
}

/** User data the extractor may use to map statement wording to categories. */
export interface ExtractionContext {
  categories: { id: string; name: string; description: string | null }[];
}

export interface ExtractedStatement {
  bank: string | null;
  cardLast4: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  /** Main currency of the statement when it can be told, else null. */
  currency: string | null;
  summaries: CurrencySummary[];
  /** Every exchange rate printed on the statement (any currency pair). */
  exchangeRates: StatementExchangeRate[];
  loyaltyPrograms: LoyaltyProgram[];
  detectedRates: DetectedRate[];
  transactions: ExtractedTransaction[];
}

/** A category of the user offered to the classifier as a target. */
export interface CategoryCandidate {
  id: string;
  name: string;
  description: string | null;
  /** Registered merchants of the category, as examples. */
  merchants: { id: string; name: string }[];
}

export interface LineClassification {
  /** The statement descriptor this verdict is about. */
  descriptor: string;
  categoryId: string | null;
  /** Set only when the line is a registered merchant of the user. */
  matchedMerchantId: string | null;
  /** 0..1 */
  confidence: number;
  /** Short explanation (never used in calculations). */
  reason: string;
}

export interface ClassificationResult {
  results: LineClassification[];
  /** Descriptors whose batch failed; the caller degrades with a warning. */
  unclassified: string[];
  /** Model that answered; null when every batch failed. */
  model: string | null;
}
