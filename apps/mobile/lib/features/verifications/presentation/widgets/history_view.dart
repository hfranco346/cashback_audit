import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import 'history_row.dart';

/// Pure presentational verification history: per-card filter, pending
/// entries first, then the finished audits. Works from the offline cache
/// (a banner says so).
class HistoryView extends StatelessWidget {
  const HistoryView({
    super.key,
    required this.cards,
    required this.cardFilter,
    required this.onCardFilter,
    required this.items,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.offline,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onOpen,
    required this.confirmDelete,
    this.errorMessage,
    this.cachedAt,
  });

  final List<CreditCard> cards;
  final String? cardFilter;
  final ValueChanged<String?> onCardFilter;
  final List<VerificationSummary> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool offline;

  /// When the offline data was saved; the banner shows it when known.
  final DateTime? cachedAt;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<VerificationSummary> onOpen;

  /// Asks for confirmation and deletes; resolves true when removed.
  final Future<bool> Function(VerificationSummary) confirmDelete;

  /// Card snapshot of the entry, falling back to the live card list.
  ({String name, String? last4, bool deleted}) _card(
    BuildContext context,
    VerificationSummary s,
  ) {
    final snap = s.card;
    if (snap != null) {
      return (name: snap.alias, last4: snap.last4, deleted: snap.deleted);
    }
    for (final c in cards) {
      if (c.id == s.cardId) {
        return (name: c.alias, last4: c.last4, deleted: false);
      }
    }
    return (
      name: s.statement.bank ?? context.l10n.historyCardUnknown,
      last4: s.statement.cardLast4,
      deleted: false,
    );
  }

  Widget _row(
    BuildContext context,
    VerificationSummary item, {
    required bool boxed,
  }) {
    final card = _card(context, item);
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDelete(item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(boxed ? 18 : 0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.delete,
              style: TextStyle(
                color: scheme.onError,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: scheme.onError),
          ],
        ),
      ),
      child: HistoryRow(
        summary: item,
        cardName: card.name,
        cardLast4: card.last4,
        cardDeleted: card.deleted,
        boxed: boxed,
        onTap: () => onOpen(item),
        onLongPress: () => confirmDelete(item),
      ),
    );
  }

  /// `8 nov, 6:40 p. m.` / `Nov 8, 6:40 PM` in the active language.
  static String _when(BuildContext context, DateTime at) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    final locale = en ? 'en_US' : 'es_MX';
    final local = at.toLocal();
    return '${DateFormat.MMMd(locale).format(local)}, '
        '${DateFormat.jm(locale).format(local)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pending = [
      for (final i in items)
        if (!i.isCompleted) i,
    ];
    final done = [
      for (final i in items)
        if (i.isCompleted) i,
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.historyTitle,
                  style: theme.textTheme.headlineLarge,
                ),
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
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (offline) ...[
                          InlineNotice(
                            key: const Key('history-offline'),
                            kind: StatusKind.neutral,
                            message: cachedAt == null
                                ? l10n.historyOfflineUndated
                                : l10n.historyOffline(
                                    _when(context, cachedAt!),
                                  ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (cards.length > 1) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                AppChip(
                                  key: const Key('filter-all'),
                                  label: l10n.allCards,
                                  selected: cardFilter == null,
                                  onTap: () => onCardFilter(null),
                                ),
                                for (final c in cards) ...[
                                  const SizedBox(width: 8),
                                  AppChip(
                                    key: Key('filter-${c.id}'),
                                    label: c.alias,
                                    selected: cardFilter == c.id,
                                    onTap: () => onCardFilter(c.id),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (errorMessage != null) ...[
                          InlineNotice(
                            message: errorMessage!,
                            actionLabel: l10n.retry,
                            onAction: () => onRefresh(),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (items.isEmpty && errorMessage == null)
                          SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.45,
                            child: EmptyState(
                              icon: Icons.history_rounded,
                              title: l10n.historyEmptyTitle,
                              message: l10n.historyEmptyBody,
                            ),
                          ),
                        if (pending.isNotEmpty) ...[
                          SectionHeader(
                            title: l10n.historyPending,
                            caption: true,
                          ),
                          const SizedBox(height: 14),
                          for (final (i, item) in pending.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: StaggeredEntrance(
                                index: i,
                                child: _row(context, item, boxed: true),
                              ),
                            ),
                        ],
                        if (done.isNotEmpty) ...[
                          SectionHeader(
                            title: l10n.historyCompleted,
                            caption: true,
                          ),
                          const SizedBox(height: 14),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (final (i, item) in done.indexed) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  StaggeredEntrance(
                                    index: i,
                                    child: _row(context, item, boxed: false),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: loadingMore
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : AppButton.ghost(
                                    key: const Key('load-more'),
                                    label: l10n.loadMore,
                                    onPressed: onLoadMore,
                                  ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
