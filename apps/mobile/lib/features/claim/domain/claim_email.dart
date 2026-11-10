import 'package:decimal/decimal.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import '../../../core/utils/decimal_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../cards/domain/card_entities.dart';
import '../../verifications/domain/verification_entities.dart';
import '../../verifications/presentation/format_reward.dart';

enum ClaimTone { formal, firm }

/// Language of the email. Independent of the app language.
enum ClaimLanguage {
  es,
  en;

  Locale get locale => Locale(name);

  /// `intl` locale for numbers.
  String get intlName => this == es ? 'es_MX' : 'en_US';

  static ClaimLanguage fromCode(String code) =>
      code.toLowerCase().startsWith('en') ? en : es;
}

/// One breakdown line as it is quoted in the email.
class ClaimLine extends Equatable {
  const ClaimLine({
    required this.categoryName,
    required this.ratePercent,
    required this.spend,
    required this.transactionCount,
    required this.expectedReward,
  });

  /// Null for the base-rate line.
  final String? categoryName;
  final Decimal ratePercent;
  final Decimal spend;
  final int transactionCount;
  final Decimal expectedReward;

  @override
  List<Object?> get props => [
    categoryName,
    ratePercent,
    spend,
    transactionCount,
    expectedReward,
  ];
}

/// Everything the claim email quotes, taken from a real verification. Bank
/// and program names stay exactly as the statement prints them.
class ClaimData extends Equatable {
  const ClaimData({
    required this.last4,
    required this.unit,
    required this.currency,
    required this.rewardCurrency,
    required this.reported,
    required this.expected,
    required this.difference,
    required this.lines,
    this.bank,
    this.program,
    this.periodStart,
    this.periodEnd,
    this.fallbackDate,
    this.userName,
  });

  /// Builds the claim data of an underpaid [v]. [card] fills what the
  /// statement did not print (bank, last 4, program).
  factory ClaimData.fromVerification(
    Verification v, {
    CreditCard? card,
    String? userName,
  }) {
    String? clean(String? s) {
      final t = s?.trim();
      return t == null || t.isEmpty ? null : t;
    }

    final reported = v.reported?.amount ?? Decimal.zero;
    final expected = v.expectedAmount ?? Decimal.zero;
    return ClaimData(
      bank: clean(v.statement.bank) ?? clean(card?.bank),
      program:
          clean(v.reported?.label) ??
          clean(v.loyalty.selectedProgram?.name) ??
          clean(card?.rewardProgramName),
      last4: clean(v.statement.cardLast4) ?? card?.last4 ?? '',
      unit: v.unit,
      currency: v.currency,
      rewardCurrency: v.resolvedRewardCurrency,
      reported: reported,
      expected: expected,
      difference: v.difference ?? reported - expected,
      periodStart: v.statement.periodStart,
      periodEnd: v.statement.periodEnd,
      fallbackDate: v.createdAt.toLocal(),
      userName: clean(userName),
      lines: [
        for (final b in v.breakdown)
          if (b.transactionCount > 0 || b.expectedReward > Decimal.zero)
            ClaimLine(
              categoryName: b.isBase ? null : b.categoryName,
              ratePercent: b.ratePercent,
              spend: b.spend,
              transactionCount: b.transactionCount,
              expectedReward: b.expectedReward,
            ),
      ],
    );
  }

  final String? bank;
  final String? program;
  final String last4;
  final RewardUnit unit;

  /// Card currency (spend and per-line rewards).
  final String currency;

  /// Currency of the audited totals.
  final String rewardCurrency;
  final Decimal reported;
  final Decimal expected;

  /// `reported - expected` (negative when underpaid).
  final Decimal difference;
  final List<ClaimLine> lines;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Used when the statement printed no period.
  final DateTime? fallbackDate;
  final String? userName;

  @override
  List<Object?> get props => [
    bank,
    program,
    last4,
    unit,
    currency,
    rewardCurrency,
    reported,
    expected,
    difference,
    lines,
    periodStart,
    periodEnd,
    fallbackDate,
    userName,
  ];
}

/// The subject and body ready to copy or hand to a mail app.
class ClaimEmail extends Equatable {
  const ClaimEmail({required this.subject, required this.body});

  final String subject;
  final String body;

  @override
  List<Object?> get props => [subject, body];
}

const _monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _monthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Deterministic claim template (no AI): builds the email in [language]
/// whatever the app language is, from the generated localizations.
abstract final class ClaimEmailBuilder {
  static ClaimEmail build(
    ClaimData data, {
    required ClaimLanguage language,
    required ClaimTone tone,
  }) {
    final l = lookupAppLocalizations(language.locale);
    final loc = language.intlName;
    final kind = data.unit == RewardUnit.points ? 'points' : 'cashback';
    String total(Decimal d) =>
        formatReward(d, data.unit, currency: data.rewardCurrency, locale: loc);
    String line(Decimal d) =>
        formatReward(d, data.unit, currency: data.currency, locale: loc);

    // The formal text spells the dates out; the firm one and the subject
    // use the compact form.
    final period = _period(
      data,
      language,
      long: tone == ClaimTone.formal,
      words: true,
    );
    final subject = l.claimSubject(
      kind,
      data.last4,
      _period(data, language, long: false, words: false),
    );

    final reportedAmount = total(data.reported);
    final reportedPhrase = data.program == null
        ? l.claimReportsStatement(reportedAmount)
        : l.claimReportsProgram(data.program!, reportedAmount);

    final details = [
      for (final c in data.lines)
        l.claimLine(
          c.categoryName ?? l.claimBaseCategory,
          formatRate(c.ratePercent, locale: loc),
          formatMoney(c.spend, currency: data.currency, locale: loc),
          c.transactionCount,
          line(c.expectedReward),
        ),
    ].join('\n');

    final parts = <String>[
      data.bank == null ? l.claimGreetingGeneric : l.claimGreeting(data.bank!),
      if (tone == ClaimTone.formal)
        l.claimFormalIntro(kind, data.last4, period, reportedPhrase)
      else
        l.claimFirmIntro(kind, data.last4, period, reportedAmount),
      if (details.isNotEmpty) details,
      l.claimTotalExpected(total(data.expected)),
      if (tone == ClaimTone.formal)
        l.claimFormalAsk
      else
        l.claimFirmAsk(total(data.difference.abs())),
      [l.claimClosing, ?data.userName].join('\n'),
    ];
    return ClaimEmail(subject: subject, body: parts.join('\n\n'));
  }

  /// `3 de octubre al 3 de noviembre de 2026`, `3 oct al 3 nov 2026` (the
  /// Spanish [words] joiner is "al", otherwise an en dash) or the English
  /// `October 3 – November 3, 2026`.
  static String _period(
    ClaimData d,
    ClaimLanguage lang, {
    required bool long,
    required bool words,
  }) {
    final start = d.periodStart;
    final end = d.periodEnd;
    if (start == null || end == null) {
      final date = d.fallbackDate ?? start ?? end;
      return date == null ? '' : _date(date, lang, long: long, year: true);
    }
    final sameYear = start.year == end.year;
    final from = _date(start, lang, long: long, year: !sameYear);
    final to = _date(end, lang, long: long, year: true);
    final joiner = lang == ClaimLanguage.es && words ? 'al' : '–';
    return '$from $joiner $to';
  }

  static String _date(
    DateTime d,
    ClaimLanguage lang, {
    required bool long,
    required bool year,
  }) {
    final m = d.month - 1;
    if (lang == ClaimLanguage.es) {
      final month = long ? _monthsEs[m] : _monthsEs[m].substring(0, 3);
      final sep = long ? ' de ' : ' ';
      final head = '${d.day}$sep$month';
      return year ? '$head$sep${d.year}' : head;
    }
    final month = long ? _monthsEn[m] : _monthsEn[m].substring(0, 3);
    final head = '$month ${d.day}';
    return year ? '$head, ${d.year}' : head;
  }
}
