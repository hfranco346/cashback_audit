import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/strings.dart';
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
    final f = DateFormat.yMMMd('es_MX');
    final s = summary.statement;
    if (s.periodStart != null && s.periodEnd != null) {
      return '${f.format(s.periodStart!)} – ${f.format(s.periodEnd!)}';
    }
    return f.format(summary.createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = VerdictStyle.of(context, summary.verdict);
    final currency = summary.statement.currency ?? 'MXN';
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
                      summary.difference,
                      summary.unit,
                      currency: currency,
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: style.color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${S.expectedLabel} ${formatReward(summary.expectedAmount, summary.unit, currency: currency)}',
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
