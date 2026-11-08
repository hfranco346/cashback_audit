import type { Decimal } from 'decimal.js';
import type { RewardUnit } from '../../cards/domain/card.js';
import type {
  CurrencySubtotal,
  ExcludedReason,
  Verdict,
} from './reward-calculator.js';
import type { ProgramSelectionSource } from './loyalty-program-selector.js';
import type { AppliedRateSource } from './rate-proposal.js';
import type {
  CurrencySummary,
  DetectedRate,
  LoyaltyProgram,
  StatementExchangeRate,
  TransactionKind,
} from './statement.js';

/**
 * KEYWORD: a registered merchant's name/keyword matched.
 * AI_MERCHANT: the classifier matched a registered merchant.
 * AI_CATEGORY: the classifier chose a category only.
 * USER: the user assigned the category by hand.
 * (Stored rows written before this change say `AI`; they are read as AI_MERCHANT.)
 */
export type MatchSource =
  'KEYWORD' | 'AI_MERCHANT' | 'AI_CATEGORY' | 'USER' | 'NONE';

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
  /** Short classifier explanation for AI matches. */
  matchReason: string | null;
  /** Null until the rates are confirmed. */
  appliedRatePercent: Decimal | null;
  /** True when a card rule (not the base rate) was applied. */
  ruleApplied: boolean;
  /** Before monthly caps. Negative for credits. Null until rates are confirmed. */
  expectedReward: Decimal | null;
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

export type VerificationStatus = 'AWAITING_RATES' | 'COMPLETED';

/** The rate used for one category (or the base) in a completed audit. */
export interface AppliedCategoryRate {
  categoryId: string;
  categoryName: string | null;
  ratePercent: Decimal;
  monthlyCap: Decimal | null;
  source: AppliedRateSource;
}

/**
 * Primary -> reward currency rate used for a completed audit. `rate` is
 * primary-currency units per 1 reward-currency unit (25.80 = 25.80 HNL per
 * USD when the card is HNL and the reward is USD).
 */
export interface AppliedRewardRate {
  fromCurrency: string;
  toCurrency: string;
  rate: Decimal;
  source: 'STATEMENT_CONFIRMED' | 'USER_ENTERED';
}

/** Exactly the rates a verification was audited with. */
export interface AppliedRates {
  baseRatePercent: Decimal;
  baseSource: AppliedRateSource;
  categoryRates: AppliedCategoryRate[];
  savedToCard: boolean;
  /** Null when the reward is not converted to another currency. */
  rewardExchangeRate: AppliedRewardRate | null;
}

export interface VerificationConversion {
  /** Single rate sent without a currency (applied to any foreign currency). */
  requestedRate: Decimal | null;
  /** Rates sent per foreign currency (primary units per 1 foreign unit). */
  requestedRates: Record<string, Decimal>;
  /** Primary -> reward currency rate sent by the user, if any. */
  requestedRewardRate: Decimal | null;
  /** Every rate printed on the statement. */
  statementRates: StatementExchangeRate[];
  currencies: CurrencySubtotal[];
  /** Reward-currency conversion of the last audit; null if none was needed. */
  reward: {
    fromCurrency: string;
    toCurrency: string;
    rate: Decimal;
    source: AppliedRewardRate['source'];
    /** Expected reward in the primary currency, before conversion. */
    expectedInPrimary: Decimal;
  } | null;
}

export interface VerificationLoyalty {
  /** Program name asked for at upload / confirm time. */
  requestedProgramName: string | null;
  /** Reward figure the user typed, if any (wins over the statement). */
  reportedOverride: Decimal | null;
  selected: LoyaltyProgram | null;
  selectedBy: ProgramSelectionSource | null;
  programs: LoyaltyProgram[];
}

/** Which model performed each step; classification is null when skipped/failed. */
export interface VerificationModels {
  extraction: string;
  classification: string | null;
  /** Model that wrote the narrative explanation; null when there is none. */
  explanation: string | null;
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
  status: VerificationStatus;
  /** Reward figures are null while AWAITING_RATES. */
  reportedAmount: Decimal | null;
  reportedUnit: RewardUnit;
  /** Currency of reported/expected/difference/tolerance; null for points. */
  rewardCurrency: string | null;
  reportedLabel: string | null;
  reportedSource: 'STATEMENT' | 'OVERRIDE' | null;
  expectedAmount: Decimal | null;
  difference: Decimal | null;
  tolerance: Decimal | null;
  verdict: Verdict | null;
  detectedRates: DetectedRate[];
  appliedRates: AppliedRates | null;
  /** Short narrative of the result; never used in calculations. */
  explanation: string | null;
  summaries: CurrencySummary[];
  conversion: VerificationConversion;
  loyalty: VerificationLoyalty;
  breakdown: VerificationBreakdownLine[];
  transactions: VerificationTransaction[];
  warnings: VerificationWarning[];
  /** @deprecated Same as models.extraction. */
  model: string;
  models: VerificationModels;
  createdAt: Date;
}

/** `id` may be pre-generated (the credit reservation references it). */
export type NewVerification = Omit<Verification, 'id' | 'createdAt'> & {
  id?: string;
};

/** Fields that can change after creation (confirm / recalculate / corrections). */
export type VerificationUpdate = Partial<
  Omit<NewVerification, 'userId' | 'cardId'>
>;

export type VerificationSummary = Omit<
  Verification,
  | 'breakdown'
  | 'transactions'
  | 'warnings'
  | 'summaries'
  | 'conversion'
  | 'loyalty'
  | 'detectedRates'
  | 'appliedRates'
  | 'explanation'
>;
