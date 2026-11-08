import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../domain/verification_entities.dart';

/// Every loyalty program printed on the statement with all its columns; the
/// audited one is highlighted. [cumulativeWarning] flags that the audited
/// figure may be a running balance instead of what was earned this period.
class LoyaltyTable extends StatelessWidget {
  const LoyaltyTable({
    super.key,
    required this.loyalty,
    required this.currency,
    this.cumulativeWarning = false,
  });

  final LoyaltyInfo loyalty;
  final String currency;
  final bool cumulativeWarning;

  String _value(Decimal? v, LoyaltyProgram p) {
    final unit = p.unit;
    if (v == null) return '—';
    return switch (unit) {
      'POINTS' => formatPoints(v),
      'CURRENCY' => formatMoney(v, currency: p.currency ?? currency),
      'MILES' => '${formatPoints(v).replaceAll(' pts', '')} mi',
      _ => formatPoints(v).replaceAll(' pts', ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (loyalty.programs.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final status = context.statusColors;
    final verdicts = context.verdictColors;
    final selected = loyalty.selectedProgram?.name;
    DataColumn col(String label) =>
        DataColumn(label: Text(label), numeric: true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.loyaltyTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            key: const Key('loyalty-table'),
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 20,
              dataRowMinHeight: 64,
              dataRowMaxHeight: 76,
              columns: [
                const DataColumn(label: Text(S.loyaltyProgram)),
                col(S.loyaltyAccumulated),
                col(S.loyaltyAvailable),
                col(S.loyaltyRedeemed),
                col(S.loyaltyExpiring),
                col(S.loyaltyForfeited),
              ],
              rows: [
                for (final p in loyalty.programs)
                  DataRow(
                    key: ValueKey('program-row-${p.name}'),
                    selected: p.name == selected,
                    color: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? status.successContainer.withValues(alpha: 0.6)
                          : null,
                    ),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: theme.textTheme.titleSmall),
                            if (p.name == selected)
                              Wrap(
                                spacing: 6,
                                children: [
                                  Text(
                                    S.loyaltyAudited,
                                    key: const Key('audited-label'),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: status.success,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (cumulativeWarning)
                                    Container(
                                      key: const Key('cumulative-chip'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: verdicts.warningContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        S.loyaltyCumulativeChip,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: verdicts.warning,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      DataCell(Text(_value(p.accumulated, p))),
                      DataCell(Text(_value(p.available, p))),
                      DataCell(Text(_value(p.redeemedInPeriod, p))),
                      DataCell(Text(_value(p.expiring, p))),
                      DataCell(Text(_value(p.forfeited, p))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
