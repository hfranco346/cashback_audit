import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/domain/card_entities.dart';
import '../../domain/verification_entities.dart';
import '../format_reward.dart';

/// Per-currency subtotals of a multi-currency statement.
class CurrencySubtotals extends StatelessWidget {
  const CurrencySubtotals({
    super.key,
    required this.subtotals,
    required this.primaryCurrency,
    required this.unit,
  });

  final List<CurrencySubtotal> subtotals;
  final String primaryCurrency;
  final RewardUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.currenciesTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < subtotals.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _Row(
                  subtotal: subtotals[i],
                  primaryCurrency: primaryCurrency,
                  unit: unit,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.subtotal,
    required this.primaryCurrency,
    required this.unit,
  });

  final CurrencySubtotal subtotal;
  final String primaryCurrency;
  final RewardUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subtotal;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      key: Key('currency-${s.currency}'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.currency, style: theme.textTheme.titleSmall),
              const Spacer(),
              if (s.expectedReward != null)
                Text(
                  formatReward(
                    s.expectedReward!,
                    unit,
                    currency: primaryCurrency,
                  ),
                  style: theme.textTheme.titleSmall,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${S.currencySpent}: ${formatMoney(s.spent, currency: s.currency)}',
            style: muted,
          ),
          if (!s.isPrimary && s.exchangeRate != null)
            Text(
              S.currencyRate(
                s.currency,
                primaryCurrency,
                decimalToApi(s.exchangeRate!),
              ),
              style: muted,
            ),
          if (s.excludedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                S.currencyExcluded(s.excludedCount),
                key: Key('currency-excluded-${s.currency}'),
                style: muted?.copyWith(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
