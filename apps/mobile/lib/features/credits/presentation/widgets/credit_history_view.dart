import '../../../../core/l10n/active_locale.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/empty_state.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../domain/credit_entities.dart';

String creditReasonLabel(CreditReason r) => switch (r) {
  CreditReason.grantFree => S.creditReasonGrantFree,
  CreditReason.grantPlan => S.creditReasonGrantPlan,
  CreditReason.grantPack => S.creditReasonGrantPack,
  CreditReason.consume => S.creditReasonConsume,
  CreditReason.refund => S.creditReasonRefund,
  CreditReason.expirePlan => S.creditReasonExpirePlan,
  CreditReason.other => S.creditReasonOther,
};

String creditBucketLabel(CreditBucket b) => switch (b) {
  CreditBucket.free => S.creditBucketFree,
  CreditBucket.plan => S.creditBucketPlan,
  CreditBucket.purchased => S.creditBucketPurchased,
};

/// Pure presentational credit ledger.
class CreditHistoryView extends StatelessWidget {
  const CreditHistoryView({
    super.key,
    required this.items,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onRefresh,
    required this.onLoadMore,
    this.errorMessage,
  });

  final List<CreditHistoryEntry> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.creditsHistoryTitle)),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: Builder(
          builder: (context) {
            if (loading && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: S.creditsHistoryEmptyTitle,
                      message: S.creditsHistoryEmptyBody,
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length + 1,
              itemBuilder: (context, i) {
                if (i == items.length) {
                  if (!hasMore) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: loadingMore
                        ? const Center(child: CircularProgressIndicator())
                        : OutlinedButton(
                            key: const Key('credits-load-more'),
                            onPressed: onLoadMore,
                            child: Text(S.loadMore),
                          ),
                  );
                }
                return StaggeredEntrance(
                  index: i,
                  child: CreditHistoryTile(entry: items[i]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CreditHistoryTile extends StatelessWidget {
  const CreditHistoryTile({super.key, required this.entry});

  final CreditHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = context.statusColors;
    final positive = entry.delta > 0;
    final color = positive ? status.success : status.danger;
    final date = DateFormat.yMMMd(ActiveLocale.intlName)
        .add_jm()
        .format(entry.createdAt.toLocal());
    return Card(
      child: ListTile(
        key: Key('credit-${entry.id}'),
        leading: Icon(
          positive ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
          color: color,
        ),
        title: Text(creditReasonLabel(entry.reason)),
        subtitle: Text('${creditBucketLabel(entry.bucket)} · $date'),
        trailing: Text(
          positive ? '+${entry.delta}' : '${entry.delta}',
          key: Key('credit-delta-${entry.id}'),
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
