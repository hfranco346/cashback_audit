import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../result_controller.dart' show TransactionFilter;
import 'transaction_tile.dart';

/// Summary line, All / In category / Not in category filter and the list.
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
  });

  /// All transactions of the verification (counts are computed from these).
  final List<VerificationTransaction> transactions;
  final TransactionFilter filter;
  final ValueChanged<TransactionFilter> onFilterChanged;
  final String currency;
  final RewardUnit unit;
  final Map<int, String> assigned;
  final ValueChanged<VerificationTransaction>? onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counted = transactions.where((t) => t.inCategory).length;
    final uncounted = transactions.length - counted;
    final visible = switch (filter) {
      TransactionFilter.all => transactions,
      TransactionFilter.counted => transactions.where((t) => t.inCategory),
      TransactionFilter.uncounted => transactions.where((t) => !t.inCategory),
    }.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.transactionsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          S.transactionsSummary(counted, uncounted),
          key: const Key('tx-summary'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TransactionFilter>(
            key: const Key('tx-filter'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: TransactionFilter.all,
                label: Text(
                  S.filterWithCount(S.filterAll, transactions.length),
                ),
              ),
              ButtonSegment(
                value: TransactionFilter.counted,
                label: Text(S.filterWithCount(S.filterCounted, counted)),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              ),
              ButtonSegment(
                value: TransactionFilter.uncounted,
                label: Text(S.filterWithCount(S.filterUncounted, uncounted)),
                icon: const Icon(Icons.cancel_outlined, size: 18),
              ),
            ],
            selected: {filter},
            onSelectionChanged: (s) => onFilterChanged(s.first),
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
            ),
          ),
      ],
    );
  }
}
