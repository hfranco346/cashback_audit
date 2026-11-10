import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/verification_entities.dart';

import '../../../../core/theme/app_theme.dart';
import '../format_reward.dart';
import '../period_label.dart';

/// One history entry: card + period on the left, and either the difference
/// with its verdict pill (finished audits) or a status pill (processing,
/// waiting for the rates, failed).
class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.summary,
    required this.cardName,
    required this.onTap,
    this.onLongPress,
    this.cardLast4,
    this.cardDeleted = false,
    this.boxed = false,
  });

  final VerificationSummary summary;
  final String cardName;
  final String? cardLast4;

  /// The card was removed; the history keeps naming it.
  final bool cardDeleted;

  /// Draws its own bordered card (pending entries); finished audits share
  /// one card and only draw dividers.
  final bool boxed;
  final VoidCallback onTap;

  /// Long press (delete) shortcut; the swipe offers the same action.
  final VoidCallback? onLongPress;

  String get _period =>
      statementPeriodLabel(summary.statement, summary.createdAt);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    final body = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cardLast4 == null ? cardName : '$cardName · $cardLast4',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _period,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontSize: 12,
                      fontFeatures: appFigures,
                    ),
                  ),
                  if (cardDeleted)
                    StatusPill(
                      key: Key('deleted-card-${summary.id}'),
                      kind: StatusKind.neutral,
                      label: l10n.cardDeleted,
                      icon: Icons.delete_outline_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _trailing(context),
      ],
    );
    final padded = Padding(padding: const EdgeInsets.all(14), child: body);
    final tappable = Semantics(
      button: true,
      child: InkWell(
        key: Key('history-row-${summary.id}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: padded,
      ),
    );
    if (!boxed) return tappable;
    return Card(clipBehavior: Clip.antiAlias, child: tappable);
  }

  Widget _trailing(BuildContext context) {
    final l10n = context.l10n;
    final verdict = summary.verdict;
    if (summary.isCompleted && verdict != null) {
      final (kind, label) = switch (verdict) {
        Verdict.underpaid => (StatusKind.error, l10n.historyPillUnderpaid),
        Verdict.overpaid => (StatusKind.overpaid, l10n.historyPillOverpaid),
        Verdict.match => (StatusKind.ok, l10n.verdictPillMatch),
      };
      final diff = summary.difference;
      final sign = diff == null || diff == Decimal.zero
          ? ''
          : (diff > Decimal.zero ? '+' : '–');
      final amount = diff == null
          ? ''
          : '$sign${formatReward(diff.abs(), summary.unit, currency: summary.resolvedRewardCurrency)}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (amount.isNotEmpty)
            Text(
              amount,
              key: Key('history-diff-${summary.id}'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kind.tone(context.appColors).fg,
                fontWeight: FontWeight.w800,
                fontFeatures: appFigures,
              ),
            ),
          const SizedBox(height: 4),
          StatusPill(kind: kind, label: label, compact: true, showIcon: false),
        ],
      );
    }
    final (kind, label, icon) = switch (summary.status) {
      VerificationStatus.processing => (
        StatusKind.neutral,
        l10n.pendingProcessingTitle,
        Icons.hourglass_top_rounded,
      ),
      VerificationStatus.failed => (
        StatusKind.error,
        l10n.pendingFailedTitle,
        Icons.priority_high_rounded,
      ),
      _ => (
        StatusKind.warning,
        l10n.historyPillConfirm,
        Icons.schedule_rounded,
      ),
    };
    return StatusPill(
      key: const Key('awaiting-chip'),
      kind: kind,
      label: label,
      icon: icon,
      compact: true,
    );
  }
}
