import type { Decimal } from 'decimal.js';

/** Result of reading a statement PDF. Amounts are exact decimals. */
export interface ExtractedTransaction {
  /** ISO date `YYYY-MM-DD`. */
  date: string;
  /** Merchant text as printed on the statement. */
  merchant: string;
  /** Always positive; `isCredit` says whether it reduces the balance spent. */
  amount: Decimal;
  /** Refund / reversal / merchant credit. */
  isCredit: boolean;
}

export type ReportedRewardUnit = 'POINTS' | 'CURRENCY';

export interface ExtractedStatement {
  bank: string | null;
  cardLast4: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  currency: string | null;
  totalSpent: Decimal | null;
  totalToPay: Decimal | null;
  reportedReward: {
    amount: Decimal;
    unit: ReportedRewardUnit;
    label: string;
  } | null;
  transactions: ExtractedTransaction[];
}

/** A merchant of the user, offered to the AI for fuzzy matching. */
export interface MerchantCandidate {
  id: string;
  name: string;
  keywords: string[];
  categoryName: string;
}

export interface MerchantGuess {
  /** The statement descriptor this guess is about. */
  descriptor: string;
  merchantId: string | null;
  /** 0..1 */
  confidence: number;
}
