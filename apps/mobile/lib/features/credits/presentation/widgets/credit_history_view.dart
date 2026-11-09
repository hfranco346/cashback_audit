import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/active_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/empty_state.dart';
import '../../domain/credit_entities.dart';

String creditReasonTitle(AppLocalizations l10n, CreditReason r) => switch (r) {
  CreditReason.grantFree => l10n.creditTitleGrantFree,
  CreditReason.grantPlan => l10n.creditTitleGrantPlan,
  CreditReason.grantPack => l10n.creditTitleGrantPack,
  CreditReason.consume => l10n.creditTitleConsume,
  CreditReason.refund => l10n.creditTitleRefund,
  CreditReason.expirePlan => l10n.creditTitleExpirePlan,
  CreditReason.other => l10n.creditTitleOther,
};

String creditReasonDetail(AppLocalizations l10n, CreditReason r) => switch (r) {
  CreditReason.grantFree => l10n.creditDetailGrantFree,
  CreditReason.grantPlan => l10n.creditDetailGrantPlan,
  CreditReason.grantPack => l10n.creditDetailGrantPack,
  CreditReason.consume => l10n.creditDetailConsume,
  CreditReason.refund => l10n.creditDetailRefund,
  CreditReason.expirePlan => l10n.creditDetailExpirePlan,
  CreditReason.other => l10n.creditDetailOther,
};

String creditBucketLabel(AppLocalizations l10n, CreditBucket b) => switch (b) {
  CreditBucket.free => l10n.creditBucketFree,
  CreditBucket.plan => l10n.creditBucketPlan,
  CreditBucket.purchased => l10n.creditBucketPurchased,
};

/// Pure presentational credit ledger (immutable, newest first).
class CreditHistoryView extends StatelessWidget {
  const CreditHistoryView({
    super.key,
    required this.items,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onBack,
    this.balance,
    this.errorMessage,
  });

  final List<CreditHistoryEntry> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int? balance;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('credits-back'),
                    tooltip: l10n.profileBack,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.creditsHistoryHeading,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        Text(
                          l10n.creditsHistoryIntro,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            height: 1.45,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
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
                            height: MediaQuery.sizeOf(context).height * 0.4,
                            child: EmptyState(
                              icon: Icons.receipt_long_rounded,
                              title: l10n.creditsHistoryEmptyTitle,
                              message: l10n.creditsHistoryEmptyBody,
                            ),
                          ),
                        if (items.isNotEmpty)
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (final (i, e) in items.indexed) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  StaggeredEntrance(
                                    index: i,
                                    child: CreditHistoryTile(entry: e),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        if (hasMore)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: loadingMore
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : AppButton.ghost(
                                    key: const Key('credits-load-more'),
                                    label: l10n.loadMore,
                                    onPressed: onLoadMore,
                                  ),
                          ),
                        if (balance != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              l10n.creditsBalanceNow(balance!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
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

/// One ledger line: signed quantity, localized reason (refunds included)
/// with its detail and date, and the bucket the credit belongs to.
class CreditHistoryTile extends StatelessWidget {
  const CreditHistoryTile({super.key, required this.entry});

  final CreditHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final positive = entry.delta > 0;
    final tone = positive ? colors.success : colors.error;
    final date = DateFormat.yMMMd(ActiveLocale.intlName)
        .format(entry.createdAt.toLocal());
    final source = switch (entry.source) {
      CreditSource.system => l10n.creditSourceSystem,
      CreditSource.apple => l10n.creditSourceApple,
      CreditSource.google => l10n.creditSourceGoogle,
      // Never surfaced inside the app.
      CreditSource.web => null,
    };
    final detail = [
      creditReasonDetail(l10n, entry.reason),
      ?source,
      date,
    ].join(' · ');
    return Padding(
      key: Key('credit-${entry.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              positive
                  ? '+${entry.delta}'
                  : '${entry.delta}'.replaceFirst('-', '–'),
              key: Key('credit-delta-${entry.id}'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: tone.fg,
                fontWeight: FontWeight.w800,
                fontFeatures: appFigures,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creditReasonTitle(l10n, entry.reason),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: appFigures,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            kind: StatusKind.neutral,
            label: creditBucketLabel(l10n, entry.bucket),
            icon: Icons.circle,
          ),
        ],
      ),
    );
  }
}
