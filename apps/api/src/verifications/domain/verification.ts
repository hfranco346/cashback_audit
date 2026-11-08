import type { Decimal } from 'decimal.js';
import type { RewardUnit } from '../../cards/domain/card.js';
import type {
  CurrencySubtotal,
  ExcludedReason,
  Verdict,
} from './reward-calculator.js';
import type { ProgramSelectionSource } from './loyalty-program-selector.js';
import type {
  CurrencySummary,
  LoyaltyProgram,
  StatementExchangeRate,
  TransactionKind,
} from './statement.js';

export type MatchSource = 'KEYWORD' | 'AI' | 'NONE';

export interface VerificationTransaction {
  index: number;
  date: string;
  reference: string | null;
  merchant: string;
  /** Positive magnitude in `currency`; see isCredit. */
  amount: Decimal;
  /** ISO 4217 code of `amount`. */
  currency: string;
  isCredit: boolean;
  kind: TransactionKind;
  /** Signed amount in the card (primary) currency; null if not convertible. */
  convertedAmount: Decimal | null;
  /** Factor applied to reach the primary currency (1 = same currency). */
  exchangeRate: Decimal | null;
  rateSource: 'REQUEST' | 'STATEMENT' | null;
  /** Set when the line took no part in the calculation. */
  excludedReason: ExcludedReason | null;
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

export interface VerificationConversion {
  /** Rate sent with the request (foreign -> primary), if any. */
  requestedRate: Decimal | null;
  /** Rate printed on the statement, if any. */
  statementRate: StatementExchangeRate | null;
  currencies: CurrencySubtotal[];
}

export interface VerificationLoyalty {
  selected: LoyaltyProgram | null;
  selectedBy: ProgramSelectionSource | null;
  programs: LoyaltyProgram[];
}

export interface Verification {
  id: string;
  userId: string;
  cardId: string;
  statementBank: string | null;
  statementLast4: string | null;
  periodStart: string | null;
  periodEnd: string | null;
  /** Currency the statement declares (may be null). */
  currency: string | null;
  /** Card currency: rewards, caps and totals are expressed in it. */
  primaryCurrency: string;
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
  summaries: CurrencySummary[];
  conversion: VerificationConversion;
  loyalty: VerificationLoyalty;
  breakdown: VerificationBreakdownLine[];
  transactions: VerificationTransaction[];
  warnings: VerificationWarning[];
  model: string;
  createdAt: Date;
}

export type NewVerification = Omit<Verification, 'id' | 'createdAt'>;

export type VerificationSummary = Omit<
  Verification,
  | 'breakdown'
  | 'transactions'
  | 'warnings'
  | 'summaries'
  | 'conversion'
  | 'loyalty'
>;
