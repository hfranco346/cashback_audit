import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../cards/domain/card_entities.dart';

/// Lifecycle of a verification (see the async contract in
/// `docs/api-contract.md`): `PROCESSING` (analysis running in the backend) →
/// `AWAITING_RATES` (nothing computed yet) → `COMPLETED` (rates confirmed),
/// or `FAILED` (see [FailureCode]; the credit is refunded).
enum VerificationStatus {
  processing,
  awaitingRates,
  completed,
  failed;

  /// Rows cached before the async flow have no status: they are results.
  static VerificationStatus fromApi(String? v) => switch (v) {
    'PROCESSING' => VerificationStatus.processing,
    'AWAITING_RATES' => VerificationStatus.awaitingRates,
    'FAILED' => VerificationStatus.failed,
    _ => VerificationStatus.completed,
  };
}

/// Why a verification ended `FAILED`.
enum FailureCode {
  notAStatement,
  extractionFailed,
  interrupted;

  /// Unknown codes degrade to [extractionFailed] (generic message).
  static FailureCode? tryFromApi(String? v) => switch (v) {
    null => null,
    'NOT_A_STATEMENT' => FailureCode.notAStatement,
    'INTERRUPTED' => FailureCode.interrupted,
    _ => FailureCode.extractionFailed,
  };
}

enum Verdict {
  match,
  underpaid,
  overpaid;

  static Verdict fromApi(String v) => switch (v) {
    'UNDERPAID' => Verdict.underpaid,
    'OVERPAID' => Verdict.overpaid,
    _ => Verdict.match,
  };

  static Verdict? tryFromApi(String? v) => v == null ? null : fromApi(v);
}

/// How a line got its category. `AI` is the legacy value (split by the API
/// into the two AI_* sources); it is read as [aiMerchant].
enum MatchSource {
  keyword,
  aiMerchant,
  aiCategory,
  user,
  none;

  static MatchSource fromApi(String? v) => switch (v) {
    'KEYWORD' => MatchSource.keyword,
    'AI_MERCHANT' || 'AI' => MatchSource.aiMerchant,
    'AI_CATEGORY' => MatchSource.aiCategory,
    'USER' => MatchSource.user,
    _ => MatchSource.none,
  };

  bool get isAi => this == aiMerchant || this == aiCategory;
}

enum TransactionKind {
  purchase,
  refund,
  fee,
  interest,
  insurance,
  payment,
  other;

  static TransactionKind fromApi(String? v) => switch (v) {
    'REFUND' => TransactionKind.refund,
    'FEE' => TransactionKind.fee,
    'INTEREST' => TransactionKind.interest,
    'INSURANCE' => TransactionKind.insurance,
    'PAYMENT' => TransactionKind.payment,
    'OTHER' => TransactionKind.other,
    _ => TransactionKind.purchase,
  };

  /// Only purchases and refunds can earn a reward.
  bool get earnsReward => this == purchase || this == refund;
}

enum ExcludedReason {
  noExchangeRate,
  nonPurchaseKind,
  other;

  static ExcludedReason? fromApi(String? v) => switch (v) {
    null => null,
    'NO_EXCHANGE_RATE' => ExcludedReason.noExchangeRate,
    'NON_PURCHASE_KIND' => ExcludedReason.nonPurchaseKind,
    _ => ExcludedReason.other,
  };
}

/// How to label a credit line. A payment made to the card is never a refund.
enum CreditType {
  payment,
  refund,
  otherCredit;

  static CreditType? fromApi(String? v) => switch (v) {
    'PAYMENT' => CreditType.payment,
    'REFUND' => CreditType.refund,
    'OTHER_CREDIT' => CreditType.otherCredit,
    _ => null,
  };
}

enum RateSource {
  statement,
  cardRule,
  none;

  static RateSource fromApi(String? v) => switch (v) {
    'STATEMENT' => RateSource.statement,
    'CARD_RULE' => RateSource.cardRule,
    _ => RateSource.none,
  };
}

/// One currency column of the statement's balance summary.
class StatementSummary extends Equatable {
  const StatementSummary({
    required this.currency,
    this.previousBalance,
    this.purchasesAndCharges,
    this.purchases,
    this.chargesAndInterest,
    this.totalBalance,
  });

  final String currency;
  final Decimal? previousBalance;
  final Decimal? purchasesAndCharges;

  /// Purchases/withdrawals subtotal only (no fees or interest).
  final Decimal? purchases;
  final Decimal? chargesAndInterest;
  final Decimal? totalBalance;

  @override
  List<Object?> get props => [
    currency,
    previousBalance,
    purchasesAndCharges,
    purchases,
    chargesAndInterest,
    totalBalance,
  ];
}

class StatementInfo extends Equatable {
  const StatementInfo({
    this.bank,
    this.cardLast4,
    this.periodStart,
    this.periodEnd,
    this.currency,
    this.totalSpent,
    this.totalToPay,
    this.summaries = const [],
  });

  final String? bank;
  final String? cardLast4;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? currency;
  final Decimal? totalSpent;
  final Decimal? totalToPay;
  final List<StatementSummary> summaries;

  @override
  List<Object?> get props => [
    bank,
    cardLast4,
    periodStart,
    periodEnd,
    currency,
    totalSpent,
    totalToPay,
    summaries,
  ];
}

class ReportedReward extends Equatable {
  const ReportedReward({
    required this.amount,
    required this.unit,
    required this.fromOverride,
    this.label,
    this.currency,
  });

  final Decimal amount;
  final RewardUnit unit;

  /// Currency the bank reported the reward in (reward currency).
  final String? currency;
  final bool fromOverride;

  /// Name of the audited loyalty program, when one was chosen.
  final String? label;

  @override
  List<Object?> get props => [amount, unit, fromOverride, label, currency];
}

class BreakdownLine extends Equatable {
  const BreakdownLine({
    required this.ratePercent,
    required this.transactionCount,
    required this.spend,
    required this.uncappedReward,
    required this.expectedReward,
    required this.capped,
    this.categoryId,
    this.categoryName,
    this.monthlyCap,
  });

  /// Null for the base-rate line.
  final String? categoryId;
  final String? categoryName;
  final Decimal ratePercent;
  final int transactionCount;
  final Decimal spend;
  final Decimal uncappedReward;
  final Decimal expectedReward;
  final Decimal? monthlyCap;
  final bool capped;

  bool get isBase => categoryId == null;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    ratePercent,
    transactionCount,
    spend,
    uncappedReward,
    expectedReward,
    monthlyCap,
    capped,
  ];
}

class VerificationTransaction extends Equatable {
  const VerificationTransaction({
    required this.index,
    required this.merchant,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.kind,
    required this.matchSource,
    required this.ruleApplied,
    this.date,
    this.reference,
    this.convertedAmount,
    this.exchangeRate,
    this.excludedReason,
    this.creditType,
    this.suggestedHint,
    this.matchedMerchantId,
    this.matchedMerchantName,
    this.categoryId,
    this.categoryName,
    this.matchConfidence,
    this.matchReason,
    this.appliedRatePercent,
    this.expectedReward,
  });

  final int index;
  final DateTime? date;
  final String? reference;

  /// Raw statement descriptor.
  final String merchant;

  /// Always positive, in the line's own [currency]; [isCredit] marks refunds.
  final Decimal amount;
  final String currency;
  final bool isCredit;
  final TransactionKind kind;

  /// Signed amount in the primary currency (after confirm, when convertible).
  final Decimal? convertedAmount;
  final Decimal? exchangeRate;
  final ExcludedReason? excludedReason;

  /// How to label a credit line; null for charges.
  final CreditType? creditType;

  /// Statement wording the classifier tagged this uncategorized line with
  /// (e.g. "Restaurantes y Comida rápida").
  final String? suggestedHint;
  final String? matchedMerchantId;
  final String? matchedMerchantName;
  final String? categoryId;
  final String? categoryName;
  final MatchSource matchSource;
  final double? matchConfidence;
  final String? matchReason;

  /// Null until the rates are confirmed.
  final Decimal? appliedRatePercent;
  final bool ruleApplied;
  final Decimal? expectedReward;

  /// Payments, fees, interest, insurance, or foreign lines without a rate:
  /// they never earn a reward, so they are neither counted nor missed.
  bool get isExcluded => excludedReason != null || !kind.earnsReward;

  /// The purchase was matched to one of the user's categories.
  bool get inCategory => !isExcluded && matchSource != MatchSource.none;

  /// A purchase that is not part of any category (earns the base rate).
  bool get outOfCategory => !isExcluded && matchSource == MatchSource.none;

  /// Signed amount in its own currency: negative for refunds/credits.
  Decimal get signedAmount => isCredit ? -amount : amount;

  @override
  List<Object?> get props => [
    index,
    date,
    reference,
    merchant,
    amount,
    currency,
    isCredit,
    kind,
    convertedAmount,
    exchangeRate,
    excludedReason,
    creditType,
    suggestedHint,
    matchedMerchantId,
    matchedMerchantName,
    categoryId,
    categoryName,
    matchSource,
    matchConfidence,
    matchReason,
    appliedRatePercent,
    ruleApplied,
    expectedReward,
  ];
}

class VerificationWarning extends Equatable {
  const VerificationWarning({required this.code, required this.message});
  final String code;
  final String message;

  @override
  List<Object?> get props => [code, message];
}

/// A reward rate the statement itself states (informational).
class DetectedRate extends Equatable {
  const DetectedRate({
    required this.isBase,
    this.categoryHint,
    this.suggestedCategoryId,
    this.ratePercent,
    this.unitNote,
    this.evidence,
    this.confidence,
  });

  final bool isBase;
  final String? categoryHint;
  final String? suggestedCategoryId;
  final Decimal? ratePercent;
  final String? unitNote;
  final String? evidence;
  final double? confidence;

  @override
  List<Object?> get props => [
    isBase,
    categoryHint,
    suggestedCategoryId,
    ratePercent,
    unitNote,
    evidence,
    confidence,
  ];
}

/// One rate the user has to confirm: the base (`categoryId == null`) or a
/// category. [required] means there is no value to prefill (source NONE).
class RateProposalEntry extends Equatable {
  const RateProposalEntry({
    required this.source,
    required this.required,
    this.categoryId,
    this.categoryName,
    this.ratePercent,
    this.monthlyCap,
    this.evidence,
    this.unitNote,
  });

  final String? categoryId;
  final String? categoryName;
  final Decimal? ratePercent;
  final Decimal? monthlyCap;
  final RateSource source;
  final String? evidence;
  final String? unitNote;
  final bool required;

  bool get isBase => categoryId == null;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    ratePercent,
    monthlyCap,
    source,
    evidence,
    unitNote,
    required,
  ];
}

class AppliedCategoryRate extends Equatable {
  const AppliedCategoryRate({
    required this.categoryId,
    required this.ratePercent,
    this.categoryName,
    this.monthlyCap,
    this.source,
  });

  final String categoryId;
  final String? categoryName;
  final Decimal ratePercent;
  final Decimal? monthlyCap;
  final String? source;

  @override
  List<Object?> get props => [
    categoryId,
    categoryName,
    ratePercent,
    monthlyCap,
    source,
  ];
}

/// Rate used to convert the reward from the card currency to the reward
/// currency: primary-currency units per 1 unit of [toCurrency].
class AppliedRewardRate extends Equatable {
  const AppliedRewardRate({
    required this.fromCurrency,
    required this.toCurrency,
    required this.rate,
    this.source,
  });

  final String fromCurrency;
  final String toCurrency;
  final Decimal rate;

  /// `STATEMENT_CONFIRMED` or `USER_ENTERED`.
  final String? source;

  @override
  List<Object?> get props => [fromCurrency, toCurrency, rate, source];
}

/// Exactly the rates a completed verification was audited with.
class AppliedRates extends Equatable {
  const AppliedRates({
    required this.baseRatePercent,
    required this.categoryRates,
    this.baseSource,
    this.savedToCard = false,
    this.rewardExchangeRate,
  });

  final AppliedRewardRate? rewardExchangeRate;

  final Decimal baseRatePercent;
  final String? baseSource;
  final bool savedToCard;
  final List<AppliedCategoryRate> categoryRates;

  @override
  List<Object?> get props => [
    baseRatePercent,
    baseSource,
    savedToCard,
    categoryRates,
    rewardExchangeRate,
  ];
}

class StatementRate extends Equatable {
  const StatementRate({
    required this.from,
    required this.to,
    required this.rate,
    this.source,
  });

  final String from;
  final String to;
  final Decimal rate;
  final String? source;

  @override
  List<Object?> get props => [from, to, rate, source];
}

class ConversionInfo extends Equatable {
  const ConversionInfo({
    this.primaryCurrency,
    this.requestedRate,
    this.requestedRates = const {},
    this.requestedRewardRate,
    this.statementRates = const [],
  });

  final String? primaryCurrency;

  /// Legacy single rate applied to any foreign currency.
  final Decimal? requestedRate;

  /// Rates sent earlier, per foreign currency.
  final Map<String, Decimal> requestedRates;
  final Decimal? requestedRewardRate;

  /// Every rate printed on the statement.
  final List<StatementRate> statementRates;

  /// First statement rate (the old single `statementRate`).
  StatementRate? get statementRate => statementRates.firstOrNull;

  @override
  List<Object?> get props => [
    primaryCurrency,
    requestedRate,
    requestedRates,
    requestedRewardRate,
    statementRates,
  ];
}

/// The reward is paid in another currency than the card's: the user must
/// say how many card-currency units one reward-currency unit is worth.
class RewardConversion extends Equatable {
  const RewardConversion({
    required this.fromCurrency,
    required this.toCurrency,
    required this.required,
    required this.fromStatement,
    this.rate,
    this.note,
  });

  /// Primary (card) currency.
  final String fromCurrency;

  /// Reward currency.
  final String toCurrency;

  /// Prefilled when the statement prints it.
  final Decimal? rate;
  final bool fromStatement;
  final bool required;
  final String? note;

  @override
  List<Object?> get props => [
    fromCurrency,
    toCurrency,
    rate,
    fromStatement,
    required,
    note,
  ];
}

/// Optional rate for one foreign spend currency (leaving it empty leaves
/// that currency's purchases out of the audit).
class ExchangeRateEntry extends Equatable {
  const ExchangeRateEntry({
    required this.currency,
    required this.fromStatement,
    this.rate,
  });

  final String currency;
  final Decimal? rate;
  final bool fromStatement;

  @override
  List<Object?> get props => [currency, rate, fromStatement];
}

/// A spending kind the statement mentions that the user has no category for.
class SuggestedCategory extends Equatable {
  const SuggestedCategory({
    required this.name,
    required this.matchingTransactionCount,
    this.ratePercent,
    this.evidence,
  });

  final String name;
  final Decimal? ratePercent;
  final String? evidence;
  final int matchingTransactionCount;

  @override
  List<Object?> get props => [
    name,
    ratePercent,
    evidence,
    matchingTransactionCount,
  ];
}

/// Per-currency subtotal of a completed verification.
class CurrencySubtotal extends Equatable {
  const CurrencySubtotal({
    required this.currency,
    required this.isPrimary,
    required this.spent,
    required this.eligibleSpent,
    required this.excludedCount,
    this.convertedEligibleSpent,
    this.exchangeRate,
    this.exchangeRateSource,
    this.expectedReward,
  });

  final String currency;
  final bool isPrimary;
  final Decimal spent;
  final Decimal eligibleSpent;
  final Decimal? convertedEligibleSpent;
  final Decimal? exchangeRate;
  final String? exchangeRateSource;
  final Decimal? expectedReward;
  final int excludedCount;

  @override
  List<Object?> get props => [
    currency,
    isPrimary,
    spent,
    eligibleSpent,
    convertedEligibleSpent,
    exchangeRate,
    exchangeRateSource,
    expectedReward,
    excludedCount,
  ];
}

class LoyaltyProgram extends Equatable {
  const LoyaltyProgram({
    required this.name,
    this.unit,
    this.accumulated,
    this.available,
    this.redeemedInPeriod,
    this.expiring,
    this.forfeited,
    this.currency,
  });

  final String name;

  /// Currency of the program's amounts when it is money (may be null).
  final String? currency;

  /// `POINTS`, `CURRENCY`, `MILES` or `UNKNOWN`.
  final String? unit;
  final Decimal? accumulated;
  final Decimal? available;
  final Decimal? redeemedInPeriod;
  final Decimal? expiring;
  final Decimal? forfeited;

  @override
  List<Object?> get props => [
    name,
    unit,
    accumulated,
    available,
    redeemedInPeriod,
    expiring,
    forfeited,
    currency,
  ];
}

class LoyaltyInfo extends Equatable {
  const LoyaltyInfo({
    this.selectedProgram,
    this.programs = const [],
    this.selectedBy,
    this.requestedProgramName,
  });

  final LoyaltyProgram? selectedProgram;
  final List<LoyaltyProgram> programs;

  /// `REQUEST`, `CARD`, `ONLY_PROGRAM` or `null`.
  final String? selectedBy;
  final String? requestedProgramName;

  static const empty = LoyaltyInfo();

  /// The statement lists several programs and none was chosen yet.
  bool get needsChoice => selectedProgram == null && programs.length > 1;

  @override
  List<Object?> get props => [
    selectedProgram,
    programs,
    selectedBy,
    requestedProgramName,
  ];
}

/// Where the previous balance of a cumulative reward came from.
enum PreviousBalanceSource {
  statement('STATEMENT'),
  previousVerification('PREVIOUS_VERIFICATION'),
  user('USER'),
  previousStatement('PREVIOUS_STATEMENT');

  const PreviousBalanceSource(this.apiValue);
  final String apiValue;

  static PreviousBalanceSource? tryFromApi(Object? value) {
    for (final s in values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }
}

/// Why the backend suggests a reporting mode.
enum ReportingReason {
  statementHasPreviousBalance('STATEMENT_HAS_PREVIOUS_BALANCE'),
  cardSetting('CARD_SETTING'),
  labelSaysAccumulated('LABEL_SAYS_ACCUMULATED'),
  reportedFarAboveExpected('REPORTED_FAR_ABOVE_EXPECTED'),
  none('NONE');

  const ReportingReason(this.apiValue);
  final String apiValue;

  static ReportingReason fromApi(Object? value) =>
      values.firstWhere((r) => r.apiValue == value, orElse: () => none);
}

/// `earned = current - previous + redeemed + expired` (the backend's rule,
/// mirrored for the live preview); `null` until both balances are known.
Decimal? deriveEarned({
  required Decimal? current,
  required Decimal? previous,
  Decimal? redeemed,
  Decimal? expired,
}) => current == null || previous == null
    ? null
    : current -
          previous +
          (redeemed ?? Decimal.zero) +
          (expired ?? Decimal.zero);

/// `rewardReportingProposal` of an `AWAITING_RATES` verification: what the
/// bank's figure probably is and what is already known to derive it.
class RewardReportingProposal extends Equatable {
  const RewardReportingProposal({
    required this.mode,
    required this.suggestedMode,
    this.reason = ReportingReason.none,
    this.cardSetting = RewardReporting.auto,
    this.currentBalance,
    this.previousBalance,
    this.previousBalanceSource,
    this.previousVerificationId,
    this.previousPeriodEnd,
    this.redeemedInPeriod,
    this.expiredInPeriod,
    this.earned,
    this.previousBalanceRequired = false,
    this.programName,
    this.reportedLabel,
  });

  /// Mode to preselect (`MONTHLY` or `CUMULATIVE`).
  final RewardReporting mode;
  final RewardReporting suggestedMode;
  final ReportingReason reason;
  final RewardReporting cardSetting;

  /// The figure the statement prints.
  final Decimal? currentBalance;
  final Decimal? previousBalance;
  final PreviousBalanceSource? previousBalanceSource;
  final String? previousVerificationId;

  /// Period end of the verification the balance came from (optional field).
  final DateTime? previousPeriodEnd;
  final Decimal? redeemedInPeriod;
  final Decimal? expiredInPeriod;
  final Decimal? earned;
  final bool previousBalanceRequired;

  /// Program name and label as printed (optional: fall back to the loyalty
  /// program of the verification).
  final String? programName;
  final String? reportedLabel;

  @override
  List<Object?> get props => [
    mode,
    suggestedMode,
    reason,
    cardSetting,
    currentBalance,
    previousBalance,
    previousBalanceSource,
    previousVerificationId,
    previousPeriodEnd,
    redeemedInPeriod,
    expiredInPeriod,
    earned,
    previousBalanceRequired,
    programName,
    reportedLabel,
  ];
}

/// `rewardReporting` of a `COMPLETED` verification: how the audited figure
/// was derived.
class RewardReportingResult extends Equatable {
  const RewardReportingResult({
    required this.mode,
    this.currentBalance,
    this.previousBalance,
    this.previousBalanceSource,
    this.redeemedInPeriod,
    this.expiredInPeriod,
    this.earned,
  });

  final RewardReporting mode;
  final Decimal? currentBalance;
  final Decimal? previousBalance;
  final PreviousBalanceSource? previousBalanceSource;
  final Decimal? redeemedInPeriod;
  final Decimal? expiredInPeriod;
  final Decimal? earned;

  bool get isCumulative => mode == RewardReporting.cumulative;

  @override
  List<Object?> get props => [
    mode,
    currentBalance,
    previousBalance,
    previousBalanceSource,
    redeemedInPeriod,
    expiredInPeriod,
    earned,
  ];
}

/// What the user decided about the bank's reward figure (confirm body).
class RewardReportingInput extends Equatable {
  const RewardReportingInput({
    required this.mode,
    this.previousBalance,
    this.previousBalanceSource,
    this.rememberForCard = false,
  });

  /// `monthly` or `cumulative`.
  final RewardReporting mode;
  final Decimal? previousBalance;
  final PreviousBalanceSource? previousBalanceSource;
  final bool rememberForCard;

  @override
  List<Object?> get props => [
    mode,
    previousBalance,
    previousBalanceSource,
    rememberForCard,
  ];
}

/// A program balance read from last month's statement.
class PreviousStatementProgram extends Equatable {
  const PreviousStatementProgram({
    required this.name,
    required this.balance,
    this.periodEnd,
  });

  final String name;
  final Decimal balance;
  final DateTime? periodEnd;

  @override
  List<Object?> get props => [name, balance, periodEnd];
}

/// Answer of `POST /verifications/:id/previous-statement`.
class PreviousStatementResult extends Equatable {
  const PreviousStatementResult({
    this.programs = const [],
    this.matchedBalance,
  });

  final List<PreviousStatementProgram> programs;

  /// Balance of the program this verification audits, when it matched.
  final Decimal? matchedBalance;

  @override
  List<Object?> get props => [programs, matchedBalance];
}

class Verification extends Equatable {
  const Verification({
    required this.id,
    required this.cardId,
    required this.status,
    required this.statement,
    required this.unit,
    required this.breakdown,
    required this.transactions,
    required this.warnings,
    required this.createdAt,
    this.primaryCurrency,
    this.rewardCurrency,
    this.reported,
    this.expectedAmount,
    this.expectedInPrimaryCurrency,
    this.difference,
    this.tolerance,
    this.verdict,
    this.explanation,
    this.detectedRates = const [],
    this.rateProposal = const [],
    this.rewardConversion,
    this.exchangeRateProposal = const [],
    this.suggestedCategories = const [],
    this.appliedRates,
    this.conversion = const ConversionInfo(),
    this.currencies = const [],
    this.loyalty = LoyaltyInfo.empty,
    this.rewardReportingProposal,
    this.rewardReporting,
    this.models = const {},
    this.failureCode,
    this.seenAt,
  });

  final String id;
  final String cardId;
  final VerificationStatus status;

  /// Set when [status] is `FAILED`.
  final FailureCode? failureCode;

  /// When the user opened a finished (completed / failed) result; null = new.
  final DateTime? seenAt;
  final StatementInfo statement;

  /// Card currency: every reward figure is expressed in it.
  final String? primaryCurrency;

  /// Currency of [reported], [expectedAmount], [difference] and [tolerance].
  /// Null for points, while unconfirmed and for legacy rows (= primary).
  final String? rewardCurrency;

  /// Reward unit of the card (falls back to cashback when unknown).
  final RewardUnit unit;
  final ReportedReward? reported;

  /// Expected reward, in [rewardCurrency].
  final Decimal? expectedAmount;

  /// The same figure before the reward conversion (card currency).
  final Decimal? expectedInPrimaryCurrency;

  /// `reported - expected`; negative means the bank paid less.
  final Decimal? difference;
  final Decimal? tolerance;
  final Verdict? verdict;

  /// Short Spanish narrative of the verdict (may be missing).
  final String? explanation;
  final List<DetectedRate> detectedRates;
  final List<RateProposalEntry> rateProposal;

  /// Non-null when the reward currency differs from the card currency.
  final RewardConversion? rewardConversion;
  final List<ExchangeRateEntry> exchangeRateProposal;
  final List<SuggestedCategory> suggestedCategories;
  final AppliedRates? appliedRates;
  final ConversionInfo conversion;
  final List<CurrencySubtotal> currencies;
  final LoyaltyInfo loyalty;

  /// `AWAITING_RATES`: how the bank's reward figure is probably reported.
  final RewardReportingProposal? rewardReportingProposal;

  /// `COMPLETED`: how the audited figure was derived (always present on
  /// current servers; `mode` tells monthly from cumulative).
  final RewardReportingResult? rewardReporting;
  final List<BreakdownLine> breakdown;
  final List<VerificationTransaction> transactions;
  final List<VerificationWarning> warnings;
  final Map<String, String?> models;
  final DateTime createdAt;

  bool get isCompleted => status == VerificationStatus.completed;
  bool get isAwaitingRates => status == VerificationStatus.awaitingRates;
  bool get isProcessing => status == VerificationStatus.processing;
  bool get isFailed => status == VerificationStatus.failed;

  /// Card currency: spend, breakdown, caps and per-line rewards use it.
  String get currency => primaryCurrency ?? statement.currency ?? 'MXN';

  /// Currency of the audited reward figures (reported / expected /
  /// difference). Equals [currency] when no conversion applies.
  String get resolvedRewardCurrency => rewardCurrency ?? currency;

  /// The reward is expressed in another currency than the card's.
  bool get rewardCurrencyDiffers => resolvedRewardCurrency != currency;

  int get countedTransactions => transactions.where((t) => t.inCategory).length;
  int get uncountedTransactions =>
      transactions.where((t) => t.outOfCategory).length;
  int get excludedTransactions =>
      transactions.where((t) => t.isExcluded).length;

  /// True when at least one purchase/refund is in a currency other than the
  /// primary one (an exchange rate may be needed).
  bool get hasForeignPurchases =>
      transactions.any((t) => t.kind.earnsReward && t.currency != currency);

  bool hasWarning(String code) => warnings.any((w) => w.code == code);

  @override
  List<Object?> get props => [
    id,
    cardId,
    status,
    statement,
    primaryCurrency,
    rewardCurrency,
    unit,
    reported,
    expectedAmount,
    expectedInPrimaryCurrency,
    difference,
    tolerance,
    verdict,
    explanation,
    detectedRates,
    rateProposal,
    rewardConversion,
    exchangeRateProposal,
    suggestedCategories,
    appliedRates,
    conversion,
    currencies,
    loyalty,
    rewardReportingProposal,
    rewardReporting,
    breakdown,
    transactions,
    warnings,
    models,
    createdAt,
    failureCode,
    seenAt,
  ];
}

/// The card as it was when the verification ran (`card` in the API). It
/// survives the card's deletion, so the history keeps naming it.
class CardSnapshot extends Equatable {
  const CardSnapshot({
    required this.alias,
    required this.last4,
    this.bank,
    this.deleted = false,
  });

  final String alias;
  final String? bank;
  final String last4;
  final bool deleted;

  @override
  List<Object?> get props => [alias, bank, last4, deleted];
}

class VerificationSummary extends Equatable {
  const VerificationSummary({
    required this.id,
    required this.cardId,
    required this.status,
    required this.statement,
    required this.unit,
    required this.createdAt,
    this.primaryCurrency,
    this.rewardCurrency,
    this.reportedAmount,
    this.expectedAmount,
    this.difference,
    this.verdict,
    this.failureCode,
    this.seenAt,
    this.card,
  });

  final String id;
  final String cardId;

  /// Null for rows cached before the snapshot existed.
  final CardSnapshot? card;
  final VerificationStatus status;
  final FailureCode? failureCode;
  final DateTime? seenAt;
  final StatementInfo statement;
  final String? primaryCurrency;

  /// Currency of the reward figures; null = [primaryCurrency].
  final String? rewardCurrency;
  final RewardUnit unit;

  /// Null while the rates are not confirmed.
  final Decimal? reportedAmount;
  final Decimal? expectedAmount;
  final Decimal? difference;
  final Verdict? verdict;
  final DateTime createdAt;

  bool get isAwaitingRates => status == VerificationStatus.awaitingRates;
  bool get isProcessing => status == VerificationStatus.processing;
  bool get isFailed => status == VerificationStatus.failed;
  bool get isCompleted => status == VerificationStatus.completed;

  /// A finished (completed / failed) result the user has not opened yet.
  bool get isUnseenResult => (isCompleted || isFailed) && seenAt == null;
  String get currency => primaryCurrency ?? statement.currency ?? 'MXN';
  String get resolvedRewardCurrency => rewardCurrency ?? currency;

  @override
  List<Object?> get props => [
    id,
    cardId,
    status,
    statement,
    primaryCurrency,
    rewardCurrency,
    unit,
    reportedAmount,
    expectedAmount,
    difference,
    verdict,
    createdAt,
    failureCode,
    seenAt,
    card,
  ];
}

class VerificationPage extends Equatable {
  const VerificationPage({
    required this.items,
    required this.page,
    required this.total,
    required this.pageSize,
  });

  final List<VerificationSummary> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

/// One confirmed rate for a category (confirm request body).
class CategoryRateInput extends Equatable {
  const CategoryRateInput({
    required this.categoryId,
    required this.ratePercent,
    this.monthlyCap,
  });

  final String categoryId;
  final Decimal ratePercent;
  final Decimal? monthlyCap;

  @override
  List<Object?> get props => [categoryId, ratePercent, monthlyCap];
}

/// Body of `POST /verifications/:id/confirm`.
class ConfirmRequest extends Equatable {
  const ConfirmRequest({
    required this.baseRatePercent,
    required this.categoryRates,
    this.saveToCard = false,
    this.reportedRewardOverride,
    this.exchangeRate,
    this.exchangeRates = const {},
    this.rewardExchangeRate,
    this.rewardProgramName,
    this.rewardReporting,
  });

  final Decimal baseRatePercent;
  final List<CategoryRateInput> categoryRates;
  final bool saveToCard;
  final Decimal? reportedRewardOverride;
  final Decimal? exchangeRate;

  /// Rate per foreign spend currency: primary units per 1 unit of the key.
  final Map<String, Decimal> exchangeRates;

  /// Primary units per 1 unit of the reward currency.
  final Decimal? rewardExchangeRate;
  final String? rewardProgramName;

  /// The user's answer about the bank's figure (absent for servers that
  /// predate it and for recalculations that keep the previous decision).
  final RewardReportingInput? rewardReporting;

  /// The same rates a completed verification was audited with, for a free
  /// recalculation after a line correction.
  factory ConfirmRequest.fromApplied(AppliedRates applied) => ConfirmRequest(
    baseRatePercent: applied.baseRatePercent,
    categoryRates: [
      for (final r in applied.categoryRates)
        CategoryRateInput(
          categoryId: r.categoryId,
          ratePercent: r.ratePercent,
          monthlyCap: r.monthlyCap,
        ),
    ],
    rewardExchangeRate: applied.rewardExchangeRate?.rate,
  );

  @override
  List<Object?> get props => [
    baseRatePercent,
    categoryRates,
    saveToCard,
    reportedRewardOverride,
    exchangeRate,
    exchangeRates,
    rewardExchangeRate,
    rewardProgramName,
    rewardReporting,
  ];
}
