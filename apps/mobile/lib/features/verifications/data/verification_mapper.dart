import 'package:decimal/decimal.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';
import '../domain/verification_entities.dart';

/// Maps API JSON (and cached JSON, which may predate the current contract)
/// to entities. Parsing is deliberately tolerant: every field added after the
/// first release is optional so old cached rows never crash.
abstract final class VerificationMapper {
  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  static List<JsonMap> _maps(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) Map<String, dynamic>.from(e),
        ]
      : const [];

  static JsonMap? _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : null;

  static StatementInfo statement(JsonMap? j) => j == null
      ? const StatementInfo()
      : StatementInfo(
          bank: j['bank'] as String?,
          cardLast4: j['cardLast4'] as String?,
          periodStart: _date(j['periodStart']),
          periodEnd: _date(j['periodEnd']),
          currency: j['currency'] as String?,
          totalSpent: tryParseDecimal(j['totalSpent']),
          totalToPay: tryParseDecimal(j['totalToPay']),
          summaries: [
            for (final m in _maps(j['summaries']))
              StatementSummary(
                currency: m['currency'] as String? ?? '',
                previousBalance: tryParseDecimal(m['previousBalance']),
                purchasesAndCharges: tryParseDecimal(m['purchasesAndCharges']),
                purchases: tryParseDecimal(m['purchases']),
                chargesAndInterest: tryParseDecimal(m['chargesAndInterest']),
                totalBalance: tryParseDecimal(m['totalBalance']),
              ),
          ],
        );

  static Verification detail(JsonMap j) {
    final reported = _map(j['reported']);
    final expected = _map(j['expected']);
    final statementJson = _map(j['statement']);
    final unitRaw = (expected?['unit'] ?? reported?['unit']) as String?;
    final primary =
        j['primaryCurrency'] as String? ??
        (statementJson?['currency'] as String?);
    return Verification(
      id: j['id'] as String,
      cardId: j['cardId'] as String,
      status: VerificationStatus.fromApi(j['status'] as String?),
      failureCode: FailureCode.tryFromApi(j['failureCode'] as String?),
      seenAt: _date(j['seenAt']),
      statement: statement(statementJson),
      primaryCurrency: primary,
      rewardCurrency: _currencyCode(j['rewardCurrency']),
      unit: unitRaw == null
          ? RewardUnit.cashbackCurrency
          : RewardUnit.fromApi(unitRaw),
      reported: reported == null
          ? null
          : ReportedReward(
              amount: parseDecimal(reported['amount']),
              unit: RewardUnit.fromApi(
                (reported['unit'] as String?) ?? 'CASHBACK_CURRENCY',
              ),
              fromOverride: reported['source'] == 'OVERRIDE',
              label: reported['label'] as String?,
              currency: _currencyCode(reported['currency']),
            ),
      expectedAmount: tryParseDecimal(expected?['amount']),
      expectedInPrimaryCurrency: tryParseDecimal(
        j['expectedInPrimaryCurrency'],
      ),
      difference: tryParseDecimal(j['difference']),
      tolerance: tryParseDecimal(j['tolerance']),
      verdict: Verdict.tryFromApi(j['verdict'] as String?),
      explanation: _nonEmpty(j['explanation']),
      detectedRates: [for (final d in _maps(j['detectedRates'])) _detected(d)],
      rateProposal: [for (final p in _maps(j['rateProposal'])) _proposal(p)],
      rewardConversion: _rewardConversion(_map(j['rewardConversion'])),
      exchangeRateProposal: [
        for (final e in _maps(j['exchangeRateProposal']))
          if (_currencyCode(e['currency']) != null)
            ExchangeRateEntry(
              currency: _currencyCode(e['currency'])!,
              rate: _positive(e['rate']),
              fromStatement: e['source'] == 'STATEMENT',
            ),
      ],
      suggestedCategories: [
        for (final c in _maps(j['suggestedCategories']))
          if (_nonEmpty(c['name']) != null)
            SuggestedCategory(
              name: _nonEmpty(c['name'])!,
              ratePercent: tryParseDecimal(c['ratePercent']),
              evidence: _nonEmpty(c['evidence']),
              matchingTransactionCount:
                  (c['matchingTransactionCount'] as num?)?.toInt() ?? 0,
            ),
      ],
      appliedRates: _applied(_map(j['appliedRates'])),
      conversion: _conversion(_map(j['conversion'])),
      currencies: [for (final c in _maps(j['currencies'])) _currency(c)],
      loyalty: _loyalty(_map(j['loyalty'])),
      rewardReportingProposal: _reportingProposal(
        _map(j['rewardReportingProposal']),
      ),
      rewardReporting: _reportingResult(_map(j['rewardReporting'])),
      breakdown: [for (final b in _maps(j['breakdown'])) _line(b)],
      transactions: [
        for (final t in _maps(j['transactions'])) _transaction(t, primary),
      ],
      warnings: [
        for (final w in _maps(j['warnings']))
          VerificationWarning(
            code: w['code'] as String? ?? '',
            message: w['message'] as String? ?? '',
          ),
      ],
      models: {
        for (final e in (_map(j['models']) ?? const {}).entries)
          e.key: e.value as String?,
      },
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  static RewardReportingProposal? _reportingProposal(JsonMap? p) {
    if (p == null) return null;
    final suggested = RewardReporting.tryMode(p['suggestedMode']);
    final mode = RewardReporting.tryMode(p['mode']) ?? suggested;
    if (mode == null) return null;
    return RewardReportingProposal(
      mode: mode,
      suggestedMode: suggested ?? mode,
      reason: ReportingReason.fromApi(p['reason']),
      cardSetting: RewardReporting.fromApi(p['cardSetting']),
      currentBalance: tryParseDecimal(p['currentBalance']),
      previousBalance: tryParseDecimal(p['previousBalance']),
      previousBalanceSource: PreviousBalanceSource.tryFromApi(
        p['previousBalanceSource'],
      ),
      previousVerificationId: _nonEmpty(p['previousVerificationId']),
      previousPeriodEnd: _date(p['previousPeriodEnd']),
      redeemedInPeriod: tryParseDecimal(p['redeemedInPeriod']),
      expiredInPeriod: tryParseDecimal(p['expiredInPeriod']),
      earned: tryParseDecimal(p['earned']),
      previousBalanceRequired: p['previousBalanceRequired'] as bool? ?? false,
      programName: _nonEmpty(p['programName']),
      reportedLabel: _nonEmpty(p['reportedLabel']),
    );
  }

  static RewardReportingResult? _reportingResult(JsonMap? r) {
    final mode = RewardReporting.tryMode(r?['mode']);
    if (r == null || mode == null) return null;
    return RewardReportingResult(
      mode: mode,
      currentBalance: tryParseDecimal(r['currentBalance']),
      previousBalance: tryParseDecimal(r['previousBalance']),
      previousBalanceSource: PreviousBalanceSource.tryFromApi(
        r['previousBalanceSource'],
      ),
      redeemedInPeriod: tryParseDecimal(r['redeemedInPeriod']),
      expiredInPeriod: tryParseDecimal(r['expiredInPeriod']),
      earned: tryParseDecimal(r['earned']),
    );
  }

  static PreviousStatementResult previousStatement(JsonMap j) =>
      PreviousStatementResult(
        programs: [
          for (final p in _maps(j['programs']))
            if (_nonEmpty(p['name']) != null &&
                tryParseDecimal(p['balance']) != null)
              PreviousStatementProgram(
                name: _nonEmpty(p['name'])!,
                balance: tryParseDecimal(p['balance'])!,
                periodEnd: _date(p['periodEnd']),
              ),
        ],
        matchedBalance: tryParseDecimal(j['matchedBalance']),
      );

  static String? _nonEmpty(Object? v) {
    final s = v is String ? v.trim() : null;
    return s == null || s.isEmpty ? null : s;
  }

  /// Upper-cased ISO code, or null for missing/blank values.
  static String? _currencyCode(Object? v) {
    final s = v is String ? v.trim().toUpperCase() : '';
    return s.isEmpty ? null : s;
  }

  static Decimal? _positive(Object? v) {
    final d = tryParseDecimal(v);
    return d != null && d > Decimal.zero ? d : null;
  }

  static RewardConversion? _rewardConversion(JsonMap? c) {
    final from = _currencyCode(c?['fromCurrency']);
    final to = _currencyCode(c?['toCurrency']);
    if (c == null || from == null || to == null) return null;
    return RewardConversion(
      fromCurrency: from,
      toCurrency: to,
      rate: _positive(c['rate']),
      fromStatement: c['source'] == 'STATEMENT',
      required: c['required'] as bool? ?? false,
      note: _nonEmpty(c['note']),
    );
  }

  static DetectedRate _detected(JsonMap d) => DetectedRate(
    isBase: d['scope'] == 'BASE',
    categoryHint: d['categoryHint'] as String?,
    suggestedCategoryId: d['suggestedCategoryId'] as String?,
    ratePercent: tryParseDecimal(d['ratePercent']),
    unitNote: d['unitNote'] as String?,
    evidence: d['evidence'] as String?,
    confidence: (d['confidence'] as num?)?.toDouble(),
  );

  static RateProposalEntry _proposal(JsonMap p) => RateProposalEntry(
    categoryId: p['categoryId'] as String?,
    categoryName: p['categoryName'] as String?,
    ratePercent: tryParseDecimal(p['ratePercent']),
    monthlyCap: tryParseDecimal(p['monthlyCap']),
    source: RateSource.fromApi(p['source'] as String?),
    evidence: _nonEmpty(p['evidence']),
    unitNote: _nonEmpty(p['unitNote']),
    required: p['required'] as bool? ?? false,
  );

  static AppliedRates? _applied(JsonMap? a) => a == null
      ? null
      : AppliedRates(
          baseRatePercent: parseDecimal(a['baseRatePercent']),
          baseSource: a['baseSource'] as String?,
          savedToCard: a['savedToCard'] as bool? ?? false,
          rewardExchangeRate: _appliedRewardRate(_map(a['rewardExchangeRate'])),
          categoryRates: [
            for (final r in _maps(a['categoryRates']))
              AppliedCategoryRate(
                categoryId: r['categoryId'] as String,
                categoryName: r['categoryName'] as String?,
                ratePercent: parseDecimal(r['ratePercent']),
                monthlyCap: tryParseDecimal(r['monthlyCap']),
                source: r['source'] as String?,
              ),
          ],
        );

  static AppliedRewardRate? _appliedRewardRate(JsonMap? r) {
    final rate = _positive(r?['rate']);
    if (r == null || rate == null) return null;
    return AppliedRewardRate(
      fromCurrency: _currencyCode(r['fromCurrency']) ?? '',
      toCurrency: _currencyCode(r['toCurrency']) ?? '',
      rate: rate,
      source: r['source'] as String?,
    );
  }

  static StatementRate? _statementRate(JsonMap? s) {
    final rate = _positive(s?['rate']);
    if (s == null || rate == null) return null;
    return StatementRate(
      from: s['from'] as String? ?? '',
      to: s['to'] as String? ?? '',
      rate: rate,
      source: s['source'] as String?,
    );
  }

  static ConversionInfo _conversion(JsonMap? c) {
    if (c == null) return const ConversionInfo();
    // `statementRate` (single, deprecated) is only read for rows cached
    // before `statementRates[]` existed.
    final rates = [
      for (final s in _maps(c['statementRates'])) ?_statementRate(s),
    ];
    final legacy = _statementRate(_map(c['statementRate']));
    return ConversionInfo(
      primaryCurrency: c['primaryCurrency'] as String?,
      requestedRate: tryParseDecimal(c['requestedRate']),
      requestedRates: {
        for (final e in (_map(c['requestedRates']) ?? const {}).entries)
          if (_positive(e.value) != null)
            e.key.toUpperCase(): _positive(e.value)!,
      },
      requestedRewardRate: _positive(c['requestedRewardRate']),
      statementRates: rates.isEmpty && legacy != null ? [legacy] : rates,
    );
  }

  static CurrencySubtotal _currency(JsonMap c) => CurrencySubtotal(
    currency: c['currency'] as String? ?? '',
    isPrimary: c['isPrimary'] as bool? ?? false,
    spent: parseDecimal(c['spent']),
    eligibleSpent: parseDecimal(c['eligibleSpent']),
    convertedEligibleSpent: tryParseDecimal(c['convertedEligibleSpent']),
    exchangeRate: tryParseDecimal(c['exchangeRate']),
    exchangeRateSource: c['exchangeRateSource'] as String?,
    expectedReward: tryParseDecimal(c['expectedReward']),
    excludedCount: (c['excludedCount'] as num?)?.toInt() ?? 0,
  );

  static LoyaltyProgram _program(JsonMap p) => LoyaltyProgram(
    name: p['name'] as String? ?? '',
    unit: p['unit'] as String?,
    accumulated: tryParseDecimal(p['accumulated']),
    available: tryParseDecimal(p['available']),
    redeemedInPeriod: tryParseDecimal(p['redeemedInPeriod']),
    expiring: tryParseDecimal(p['expiring']),
    forfeited: tryParseDecimal(p['forfeited']),
    currency: _currencyCode(p['currency']),
  );

  static LoyaltyInfo _loyalty(JsonMap? l) {
    if (l == null) return LoyaltyInfo.empty;
    final selected = _map(l['selectedProgram']);
    return LoyaltyInfo(
      selectedProgram: selected == null ? null : _program(selected),
      programs: [for (final p in _maps(l['programs'])) _program(p)],
      selectedBy: l['selectedBy'] as String?,
      requestedProgramName: l['requestedProgramName'] as String?,
    );
  }

  static BreakdownLine _line(JsonMap b) => BreakdownLine(
    categoryId: b['categoryId'] as String?,
    categoryName: b['categoryName'] as String?,
    ratePercent: parseDecimal(b['ratePercent']),
    transactionCount: (b['transactionCount'] as num?)?.toInt() ?? 0,
    spend: parseDecimal(b['spend']),
    uncappedReward: parseDecimal(b['uncappedReward']),
    expectedReward: parseDecimal(b['expectedReward']),
    monthlyCap: tryParseDecimal(b['monthlyCap']),
    capped: b['capped'] as bool? ?? false,
  );

  static VerificationTransaction _transaction(JsonMap t, String? primary) {
    final isCredit = t['isCredit'] as bool? ?? false;
    final rawKind = t['kind'] as String?;
    final kind = rawKind == null
        ? (isCredit ? TransactionKind.refund : TransactionKind.purchase)
        : TransactionKind.fromApi(rawKind);
    return VerificationTransaction(
      index: (t['index'] as num).toInt(),
      date: _date(t['date']),
      reference: t['reference'] as String?,
      merchant: t['merchant'] as String? ?? '',
      amount: parseDecimal(t['amount']),
      // Rows cached before multi-currency have no currency: they were all in
      // the card currency.
      currency: t['currency'] as String? ?? primary ?? '',
      isCredit: isCredit,
      kind: kind,
      creditType: isCredit
          ? (CreditType.fromApi(t['creditType'] as String?) ??
                _legacyCreditType(kind))
          : null,
      suggestedHint: _nonEmpty(t['suggestedHint']),
      convertedAmount: tryParseDecimal(t['convertedAmount']),
      exchangeRate: tryParseDecimal(t['exchangeRate']),
      excludedReason: ExcludedReason.fromApi(t['excludedReason'] as String?),
      matchedMerchantId: t['matchedMerchantId'] as String?,
      matchedMerchantName: t['matchedMerchantName'] as String?,
      categoryId: t['categoryId'] as String?,
      categoryName: t['categoryName'] as String?,
      matchSource: MatchSource.fromApi(t['matchSource'] as String?),
      matchConfidence: (t['matchConfidence'] as num?)?.toDouble(),
      matchReason: _nonEmpty(t['matchReason']),
      appliedRatePercent: tryParseDecimal(t['appliedRatePercent']),
      ruleApplied: t['ruleApplied'] as bool? ?? false,
      expectedReward: tryParseDecimal(t['expectedReward']),
    );
  }

  /// Rows from before `creditType` existed: derive it from the line kind.
  static CreditType _legacyCreditType(TransactionKind kind) => switch (kind) {
    TransactionKind.payment => CreditType.payment,
    TransactionKind.refund => CreditType.refund,
    _ => CreditType.otherCredit,
  };

  static CardSnapshot? _cardSnapshot(Object? raw) {
    final j = _map(raw);
    final last4 = j?['last4'];
    if (j == null || last4 is! String) return null;
    return CardSnapshot(
      alias: j['alias'] as String? ?? '',
      bank: j['bank'] as String?,
      last4: last4,
      deleted: j['deleted'] as bool? ?? false,
    );
  }

  static VerificationSummary summary(JsonMap j) {
    final statementJson = _map(j['statement']);
    return VerificationSummary(
      id: j['id'] as String,
      cardId: j['cardId'] as String,
      card: _cardSnapshot(j['card']),
      status: VerificationStatus.fromApi(j['status'] as String?),
      failureCode: FailureCode.tryFromApi(j['failureCode'] as String?),
      seenAt: _date(j['seenAt']),
      statement: statement(statementJson),
      primaryCurrency:
          j['primaryCurrency'] as String? ??
          (statementJson?['currency'] as String?),
      rewardCurrency: _currencyCode(j['rewardCurrency']),
      unit: RewardUnit.fromApi(
        (j['rewardUnit'] as String?) ?? 'CASHBACK_CURRENCY',
      ),
      reportedAmount: tryParseDecimal(j['reportedAmount']),
      expectedAmount: tryParseDecimal(j['expectedAmount']),
      difference: tryParseDecimal(j['difference']),
      verdict: Verdict.tryFromApi(j['verdict'] as String?),
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }

  /// Derives the list-summary JSON from a full verification JSON so a fresh
  /// upload/confirm can be cached in the history without another request.
  static JsonMap summaryJsonFromDetail(JsonMap d) {
    final expected = _map(d['expected']);
    final reported = _map(d['reported']);
    return {
      'id': d['id'],
      'cardId': d['cardId'],
      'card': d['card'],
      'status': d['status'] ?? 'COMPLETED',
      'failureCode': d['failureCode'],
      'seenAt': d['seenAt'],
      'statement': d['statement'],
      'primaryCurrency': d['primaryCurrency'],
      'rewardCurrency': d['rewardCurrency'],
      'rewardUnit': expected?['unit'] ?? reported?['unit'],
      'reportedAmount': reported?['amount'],
      'expectedAmount': expected?['amount'],
      'difference': d['difference'],
      'verdict': d['verdict'],
      'createdAt': d['createdAt'],
    };
  }

  /// Body of `POST /verifications/:id/confirm`; decimals go out as strings.
  static JsonMap confirmBody(ConfirmRequest r) => {
    'baseRatePercent': decimalToApi(r.baseRatePercent),
    'categoryRates': [
      for (final c in r.categoryRates)
        {
          'categoryId': c.categoryId,
          'ratePercent': decimalToApi(c.ratePercent),
          'monthlyCap': c.monthlyCap == null
              ? null
              : decimalToApi(c.monthlyCap!),
        },
    ],
    'saveToCard': r.saveToCard,
    if (r.reportedRewardOverride != null)
      'reportedRewardOverride': decimalToApi(r.reportedRewardOverride!),
    if (r.exchangeRate != null) 'exchangeRate': decimalToApi(r.exchangeRate!),
    if (r.exchangeRates.isNotEmpty)
      'exchangeRates': {
        for (final e in r.exchangeRates.entries)
          e.key.toUpperCase(): decimalToApi(e.value),
      },
    if (r.rewardExchangeRate != null)
      'rewardExchangeRate': decimalToApi(r.rewardExchangeRate!),
    if (r.rewardProgramName != null && r.rewardProgramName!.trim().isNotEmpty)
      'rewardProgramName': r.rewardProgramName!.trim(),
    if (r.rewardReporting != null)
      'rewardReporting': {
        'mode': r.rewardReporting!.mode.apiValue,
        if (r.rewardReporting!.previousBalance != null)
          'previousBalance': decimalToApi(r.rewardReporting!.previousBalance!),
        if (r.rewardReporting!.previousBalanceSource != null)
          'previousBalanceSource':
              r.rewardReporting!.previousBalanceSource!.apiValue,
        'rememberForCard': r.rewardReporting!.rememberForCard,
      },
  };
}
