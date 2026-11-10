import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/period_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(() => ActiveLocale.set(const Locale('es')));

  StatementInfo period(DateTime a, DateTime b) =>
      StatementInfo(periodStart: a, periodEnd: b);
  final created = DateTime(2026, 11, 8);

  test('writes the year once when both dates share it, like the design', () {
    final s = period(DateTime(2026, 10, 3), DateTime(2026, 11, 3));
    expect(statementPeriodLabel(s, created), '3 oct – 3 nov 2026');
    ActiveLocale.set(const Locale('en'));
    expect(statementPeriodLabel(s, created), 'Oct 3 – Nov 3, 2026');
  });

  test('keeps both years across a year boundary', () {
    ActiveLocale.set(const Locale('en'));
    final s = period(DateTime(2025, 12, 20), DateTime(2026, 1, 19));
    expect(statementPeriodLabel(s, created), 'Dec 20, 2025 – Jan 19, 2026');
  });
}
