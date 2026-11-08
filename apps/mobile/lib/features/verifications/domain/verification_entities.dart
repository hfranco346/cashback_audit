import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';

import '../../cards/domain/card_entities.dart';

/// `AWAITING_RATES` after the upload (nothing computed yet); `COMPLETED`
/// after the user confirmed the rates.
enum VerificationStatus {
  awaitingRates,
  completed;

  /// Rows cached before the two-step flow have no status: they are results.
  static VerificationStatus fromApi(String? v) => v == 'AWAITING_RATES'
      ? VerificationStatus.awaitingRates
      : VerificationStatus.completed;
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
    this.models = const {},
  });

  final String id;
  final String cardId;
  final VerificationStatus status;
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
  final List<BreakdownLine> breakdown;
  final List<VerificationTransaction> transactions;
  final List<VerificationWarning> warnings;
  final Map<String, String?> models;
  final DateTime createdAt;

  bool get isCompleted => status == VerificationStatus.completed;
  bool get isAwaitingRates => status == VerificationStatus.awaitingRates;

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
    breakdown,
    transactions,
    warnings,
    models,
    createdAt,
  ];
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
  });

  final String id;
  final String cardId;
  final VerificationStatus status;
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
  ];
}
