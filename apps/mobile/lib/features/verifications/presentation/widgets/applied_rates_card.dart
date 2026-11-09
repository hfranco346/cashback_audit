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
            if (applied.rewardExchangeRate != null) ...[
              const SizedBox(height: 14),
              _RewardRateDetail(rate: applied.rewardExchangeRate!),
            ],
            if (onRecalculate != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('recalculate-button'),
                onPressed: onRecalculate,
                icon: const Icon(Icons.percent_rounded),
                label: Text(S.recalcWithOtherRates),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Conversión de la recompensa: 1 USD = 25.9969 HNL" with where it came from.
class _RewardRateDetail extends StatelessWidget {
  const _RewardRateDetail({required this.rate});

  final AppliedRewardRate rate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final origin = switch (rate.source) {
      'STATEMENT_CONFIRMED' => S.rewardRateFromStatement,
      'USER_ENTERED' => S.rewardRateUserEntered,
      _ => null,
    };
    return Column(
      key: const Key('reward-rate-detail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.rewardRateDetailTitle,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          S.rewardRateDetail(
            rate.toCurrency,
            decimalToApi(rate.rate),
            rate.fromCurrency,
          ),
          style: theme.textTheme.titleSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (origin != null)
          Text(
            origin,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
