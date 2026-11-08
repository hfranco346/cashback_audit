import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';

/// Per-category (and base rate) breakdown of the expected reward.
class BreakdownSection extends StatelessWidget {
  const BreakdownSection({
    super.key,
    required this.lines,
    required this.currency,
    required this.unit,
  });

  final List<BreakdownLine> lines;
  final String currency;
  final RewardUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.breakdownTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _Line(line: lines[i], currency: currency, unit: unit),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line, required this.currency, required this.unit});

  final BreakdownLine line;
  final String currency;
  final RewardUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = line.isBase
        ? S.baseRateLine
        : (line.categoryName ?? S.baseRateLine);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · ${formatRate(line.ratePercent)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  S.breakdownDetail(
                    formatMoney(line.spend, currency: currency),
                    line.transactionCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (line.capped && line.monthlyCap != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${S.capped} · ${S.capOf(formatReward(line.monthlyCap!, unit, currency: currency))}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formatReward(line.expectedReward, unit, currency: currency),
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
