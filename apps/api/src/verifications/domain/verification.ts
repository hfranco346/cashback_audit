import type { Decimal } from 'decimal.js';
import type { RewardUnit } from '../../cards/domain/card.js';
import type { Verdict } from './reward-calculator.js';

export type MatchSource = 'KEYWORD' | 'AI' | 'NONE';

export interface VerificationTransaction {
  index: number;
  date: string;
  merchant: string;
  /** Positive magnitude; see isCredit. */
  amount: Decimal;
  isCredit: boolean;
  matchedMerchantId: string | null;
  matchedMerchantName: string | null;
  categoryId: string | null;
  categoryName: string | null;
  matchSource: MatchSource;
  /** Only for AI matches (0..1). */
  matchConfidence: number | null;
  appliedRatePercent: Decimal;
  /** True when a card rule (not the base rate) was applied. */
  ruleApplied: boolean;
  /** Before monthly caps. Negative for credits. */
  expectedReward: Decimal;
}

export interface VerificationBreakdownLine {
  /** Null = spend that earned the base rate. */
  categoryId: string | null;
  categoryName: string | null;
  ratePercent: Decimal;
  transactionCount: number;
  spend: Decimal;
  uncappedReward: Decimal;
  expectedReward: Decimal;
  monthlyCap: Decimal | null;
  capped: boolean;
}

export interface VerificationWarning {
  code: string;
  message: string;
}

export interface Verification {
  id: string;
  userId: string;
  cardId: string;
  statementBank: string | null;
  statementLast4: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  currency: string | null;
  totalSpent: Decimal | null;
  totalToPay: Decimal | null;
  reportedAmount: Decimal;
  reportedUnit: RewardUnit;
  reportedLabel: string | null;
  reportedSource: 'STATEMENT' | 'OVERRIDE';
  expectedAmount: Decimal;
  difference: Decimal;
  tolerance: Decimal;
  verdict: Verdict;
  breakdown: VerificationBreakdownLine[];
  transactions: VerificationTransaction[];
  warnings: VerificationWarning[];
  model: string;
  createdAt: Date;
}

export type NewVerification = Omit<Verification, 'id' | 'createdAt'>;

export type VerificationSummary = Omit<
  Verification,
  'breakdown' | 'transactions' | 'warnings'
>;
