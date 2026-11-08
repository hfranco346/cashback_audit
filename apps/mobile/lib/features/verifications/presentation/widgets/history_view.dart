import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/empty_state.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import 'verification_summary_tile.dart';

/// Pure presentational verification history with a per-card filter.
class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.cards,
    required this.cardFilter,
    required this.onCardFilter,
    required this.items,
    required this.cardLabel,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.offline,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    required this.confirmDelete,
    this.errorMessage,
  });

  final List<CreditCard> cards;
  final String? cardFilter;
  final ValueChanged<String?> onCardFilter;
  final List<VerificationSummary> items;
  final String Function(String cardId) cardLabel;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool offline;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<VerificationSummary> onOpen;

  /// Asks for confirmation and deletes; resolves true when removed.
  final Future<bool> Function(VerificationSummary) confirmDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.historyTitle)),
      body: Column(
        children: [
          if (cards.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: const Key('filter-all'),
                      label: const Text(S.allCards),
                      selected: cardFilter == null,
                      onSelected: (_) => onCardFilter(null),
                    ),
                  ),
                  for (final c in cards)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: Key('filter-${c.id}'),
                        label: Text('${c.alias} · ${c.last4}'),
                        selected: cardFilter == c.id,
                        onSelected: (_) => onCardFilter(c.id),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: Builder(
                builder: (context) {
                  if (loading && items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (items.isEmpty) {
                    return ListView(
                      children: [
                        if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: InlineMessage(
                              message: errorMessage!,
                              actionLabel: S.retry,
                              onAction: () => onRefresh(),
                            ),
                          ),
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.5,
                          child: const EmptyState(
                            icon: Icons.history_rounded,
                            title: S.historyEmptyTitle,
                            message: S.historyEmptyBody,
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: items.length + 1 + (offline ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (offline && i == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: InlineMessage(
                            message: S.offlineBanner,
                            tone: InlineMessageTone.info,
                          ),
                        );
                      }
                      final index = offline ? i - 1 : i;
                      if (index == items.length) {
                        if (!hasMore) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: loadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : OutlinedButton(
                                  key: const Key('load-more'),
                                  onPressed: onLoadMore,
                                  child: const Text(S.loadMore),
                                ),
                        );
                      }
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: StaggeredEntrance(
                          index: index,
                          child: Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => confirmDelete(item),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            child: VerificationSummaryTile(
                              summary: item,
                              cardLabel: cardLabel(item.cardId),
                              onTap: () => onOpen(item),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
