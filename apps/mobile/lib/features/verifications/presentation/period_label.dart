import 'package:intl/intl.dart';

import '../../../core/l10n/active_locale.dart';
import '../domain/verification_entities.dart';

/// `Sep 21 – Oct 21, 2026` for a statement (the year is written once when
/// both dates share it); the creation date when the period is unknown.
String statementPeriodLabel(StatementInfo statement, DateTime createdAt) {
  final f = DateFormat.yMMMd(ActiveLocale.intlName);
  final start = statement.periodStart;
  final end = statement.periodEnd;
  if (start != null && end != null) {
    final first = start.year == end.year
        ? DateFormat.MMMd(ActiveLocale.intlName)
        : f;
    return '${first.format(start)} – ${f.format(end)}';
  }
  return f.format(createdAt.toLocal());
}
