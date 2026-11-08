import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../domain/verification_entities.dart';

/// The rates the audit was computed with, plus the free "recalculate" action.
class AppliedRatesCard extends StatelessWidget {
  const AppliedRatesCard({
    super.key,
    required this.applied,
    required this.onRecalculate,
  });

  final AppliedRates applied;
  final VoidCallback? onRecalculate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('applied-rates-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.appliedRatesTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    '${S.rateBaseTitle} ${formatRate(applied.baseRatePercent)}',
                  ),
                ),
                for (final r in applied.categoryRates)
                  Chip(
                    label: Text(
                      '${r.categoryName ?? ''} ${formatRate(r.ratePercent)}'
                          .trim(),
                    ),
                  ),
              ],
            ),
            if (onRecalculate != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('recalculate-button'),
                onPressed: onRecalculate,
                icon: const Icon(Icons.percent_rounded),
                label: const Text(S.recalcWithOtherRates),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
