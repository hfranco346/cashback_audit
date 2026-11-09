import '../../../../core/l10n/active_locale.dart';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';
import 'verdict_style.dart';

/// History row. [cardLabel] is e.g. "Daily · 4321".
class VerificationSummaryTile extends StatelessWidget {
  const VerificationSummaryTile({
    super.key,
    required this.summary,
    required this.cardLabel,
    required this.onTap,
  });

  final VerificationSummary summary;
  final String cardLabel;
  final VoidCallback onTap;

  String _period() {
    final f = DateFormat.yMMMd(ActiveLocale.intlName);
    final s = summary.statement;
    if (s.periodStart != null && s.periodEnd != null) {
      return '${f.format(s.periodStart!)} – ${f.format(s.periodEnd!)}';
    }
    return f.format(summary.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verdict = summary.verdict;
    if (!summary.isCompleted || verdict == null) {
      return _AwaitingTile(
        label: switch (summary.status) {
          VerificationStatus.processing => S.current.pendingProcessingTitle,
          VerificationStatus.failed => S.current.pendingFailedTitle,
          _ => S.awaitingRatesChip,
        },
        cardLabel: cardLabel,
        period: _period(),
        onTap: onTap,
      );
    }
    final style = VerdictStyle.of(context, verdict);
    final rewardCurrency = summary.resolvedRewardCurrency;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Hero(
                tag: 'verdict-${summary.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: style.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    style.icon,
                    color: theme.colorScheme.surface,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(style.label, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '$cardLabel · ${_period()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatReward(
                      summary.difference ?? Decimal.zero,
                      summary.unit,
                      currency: rewardCurrency,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: style.color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${S.expectedLabel} ${formatReward(summary.expectedAmount ?? Decimal.zero, summary.unit, currency: rewardCurrency)}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// History row of a statement whose rates were not confirmed yet.
class _AwaitingTile extends StatelessWidget {
  const _AwaitingTile({
    required this.label,
    required this.cardLabel,
    required this.period,
    required this.onTap,
  });

  final String label;
  final String cardLabel;
  final String period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verdicts = context.verdictColors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('awaiting-tile'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: verdicts.warningContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.percent_rounded, color: verdicts.warning),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const Key('awaiting-chip'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: verdicts.warningContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: verdicts.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$cardLabel · $period',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
