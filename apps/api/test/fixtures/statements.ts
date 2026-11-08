import { Decimal } from 'decimal.js';
import type {
  DetectedRate,
  ExtractedStatement,
  ExtractedTransaction,
  LoyaltyProgram,
} from '../../src/verifications/domain/statement.js';

/**
 * Synthetic extraction results with different shapes. They are what the
 * extractor returns, so the whole pipeline downstream of Claude can be
 * tested without PDFs. Bank names are examples only.
 */

export const d = (v: string | number) => new Decimal(v);

export const CAT_SUPER = 'cat-super';
export const CAT_PHARMACY = 'cat-pharmacy';

export const line = (
  merchant: string,
  amount: number,
  over: Partial<ExtractedTransaction> = {},
): ExtractedTransaction => ({
  date: '2026-01-02',
  reference: null,
  merchant,
  amount: d(amount),
  currency: 'MXN',
  isCredit: false,
  kind: 'PURCHASE',
  ...over,
});

export const program = (
  name: string,
  accumulated: string | null,
  over: Partial<LoyaltyProgram> = {},
): LoyaltyProgram => ({
  name,
  accumulated: accumulated === null ? null : d(accumulated),
  available: null,
  redeemedInPeriod: null,
  expiring: null,
  forfeited: null,
  unit: 'CURRENCY',
  currency: null,
  ...over,
});

export const detected = (over: Partial<DetectedRate> = {}): DetectedRate => ({
  scope: 'CATEGORY',
  categoryHint: null,
  suggestedCategoryId: null,
  ratePercent: null,
  unitNote: null,
  evidence: '',
  confidence: 0.9,
  ...over,
});

const base = (over: Partial<ExtractedStatement>): ExtractedStatement => ({
  bank: 'Example Bank',
  cardLast4: '4321',
  periodStart: '2026-01-01',
  periodEnd: '2026-01-31',
  currency: 'MXN',
  summaries: [],
  exchangeRates: [],
  loyaltyPrograms: [],
  detectedRates: [],
  transactions: [],
  ...over,
});

/** Single currency (MXN), one cashback program, stated rates (1% / 5% supermarkets). */
export const mxnCashbackStatement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement =>
  base({
    summaries: [
      {
        currency: 'MXN',
        previousBalance: d(0),
        purchasesAndCharges: d(1400),
        totalBalance: d(1400),
      },
    ],
    loyaltyPrograms: [program('Bonificación del periodo', '58')],
    detectedRates: [
      detected({
        scope: 'BASE',
        ratePercent: d(1),
        evidence: '1% cashback on all purchases',
      }),
      detected({
        categoryHint: 'supermarkets',
        suggestedCategoryId: CAT_SUPER,
        ratePercent: d(5),
        evidence: '5% cashback at supermarkets',
      }),
    ],
    transactions: [
      line('WAL MART SUC 123', 1000, { reference: '0001' }),
      line('WM SUPERCENTER', 200),
      line('PEMEX 4455', 300),
      line('WAL MART SUC 123', 100, { isCredit: true, kind: 'REFUND' }),
    ],
    ...over,
  });

/**
 * Dual currency (HNL/USD) with two programs (points and cash), an insurance
 * line and a payment; the rate is stated per category in the document.
 */
export const hnlUsdTwoProgramsStatement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement =>
  base({
    bank: 'BAC Credomatic (example)',
    currency: 'HNL',
    summaries: [
      {
        currency: 'HNL',
        previousBalance: d(500),
        purchasesAndCharges: d(2670),
        totalBalance: d(3170),
      },
      {
        currency: 'USD',
        previousBalance: d(0),
        purchasesAndCharges: d(40),
        totalBalance: d(40),
      },
    ],
    loyaltyPrograms: [
      program('PUNTOS BAC CREDOMATIC', '1500', {
        unit: 'POINTS',
        available: d(1400),
        redeemedInPeriod: d(100),
        forfeited: d(0),
      }),
      program('CASH BAC CREDOMATIC', '134.5', {
        available: d('134.5'),
      }),
    ],
    detectedRates: [
      detected({
        categoryHint: 'supermercados',
        suggestedCategoryId: CAT_SUPER,
        ratePercent: d(7),
        evidence: '7% cashback en supermercados',
      }),
    ],
    transactions: [
      line('SUPERMERCADO LA COLONIA', 2000, { currency: 'HNL' }),
      line('FARMACIA SIMAN', 500, { currency: 'HNL' }),
      line('AMAZON MKTPLACE', 40, { currency: 'USD' }),
      line('SEGURO DE SALDO DE DEUDA', 170, {
        currency: 'HNL',
        kind: 'INSURANCE',
      }),
      line('PAGO RECIBIDO', 500, {
        currency: 'HNL',
        kind: 'PAYMENT',
        isCredit: true,
      }),
    ],
    ...over,
  });

/** USD only, a miles program; the stated rate cannot be a percentage. */
export const usdMilesStatement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement =>
  base({
    currency: 'USD',
    summaries: [
      {
        currency: 'USD',
        previousBalance: d(0),
        purchasesAndCharges: d(800),
        totalBalance: d(800),
      },
    ],
    loyaltyPrograms: [
      program('Travel Miles', '2400', {
        unit: 'MILES',
        available: d(2400),
      }),
    ],
    detectedRates: [
      detected({
        scope: 'BASE',
        ratePercent: null,
        unitNote: '2 miles per USD 1 spent',
        evidence: 'Earn 2 miles for every $1 spent',
      }),
    ],
    transactions: [
      line('AIRLINE TICKETS', 600, { currency: 'USD' }),
      line('HOTEL STAY', 200, { currency: 'USD' }),
    ],
    ...over,
  });

/**
 * Local currency CRC with USD and EUR purchase lines, and a cashback program
 * denominated in USD (the reward currency differs from the spend currency).
 */
export const crcUsdEurStatement = (
  over: Partial<ExtractedStatement> = {},
): ExtractedStatement =>
  base({
    bank: 'Example Bank CR',
    currency: 'CRC',
    summaries: [
      {
        currency: 'CRC',
        previousBalance: d(0),
        purchasesAndCharges: d(56000),
        totalBalance: d(56000),
      },
    ],
    loyaltyPrograms: [
      program('Cashback USD', '2.6', { currency: 'USD', available: d('2.6') }),
    ],
    detectedRates: [
      detected({
        scope: 'BASE',
        ratePercent: d(1),
        evidence: '1% de cashback',
      }),
    ],
    transactions: [
      line('SUPER LOCAL', 56000, { currency: 'CRC' }),
      line('STREAMING SERVICE', 100, { currency: 'USD' }),
      line('HOTEL EUROPA', 50, { currency: 'EUR' }),
    ],
    ...over,
  });
