import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../result_controller.dart' show TransactionFilter;
import 'transaction_tile.dart';

/// Summary line, All / In category / Not in category / Excluded filter and
/// the list of statement lines.
class TransactionsSection extends StatelessWidget {
  const TransactionsSection({
    super.key,
    required this.transactions,
    required this.filter,
    required this.onFilterChanged,
    required this.currency,
    required this.unit,
    this.assigned = const {},
    this.onAssign,
    this.onCorrect,
  });

  /// All transactions of the verification (counts are computed from these).
  final List<VerificationTransaction> transactions;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;
  final String currency;
  final RewardUnit unit;
  final Map<int, String> assigned;
  final ValueChanged<VerificationTransaction>? onAssign;

  /// Tap on a counted/uncounted line to change its category.
  final ValueChanged<VerificationTransaction>? onCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counted = transactions.where((t) => t.inCategory).length;
    final uncounted = transactions.where((t) => t.outOfCategory).length;
    final excluded = transactions.where((t) => t.isExcluded).length;
    final visible = switch (filter) {
      TransactionFilter.all => transactions,
      TransactionFilter.counted => transactions.where((t) => t.inCategory),
      TransactionFilter.uncounted => transactions.where((t) => t.outOfCategory),
      TransactionFilter.excluded => transactions.where((t) => t.isExcluded),
    }.toList();
    final options = <(TransactionFilter, String, int)>[
      (TransactionFilter.all, S.filterAll, transactions.length),
      (TransactionFilter.counted, S.filterCounted, counted),
      (TransactionFilter.uncounted, S.filterUncounted, uncounted),
      (TransactionFilter.excluded, S.filterExcluded, excluded),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.transactionsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          S.transactionsSummary(counted, uncounted, excluded),
          key: const Key('tx-summary'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          key: const Key('tx-filter'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (value, label, count) in options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('filter-${value.name}'),
                    label: Text(S.filterWithCount(label, count)),
                    selected: filter == value,
                    onSelected: (_) => onFilterChanged(value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text(S.noTransactionsMatch)),
          ),
        for (final tx in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TransactionTile(
              transaction: tx,
              currency: currency,
              unit: unit,
              assignedCategory: assigned[tx.index],
              onAssign: onAssign == null ? null : () => onAssign!(tx),
              onTap: onCorrect == null ? null : () => onCorrect!(tx),
            ),
          ),
      ],
    );
  }
}
