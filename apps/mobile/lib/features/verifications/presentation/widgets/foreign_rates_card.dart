import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../confirm_rates_controller.dart';
import 'rate_entry_card.dart';

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// One optional exchange rate per foreign spend currency. An empty field
/// leaves that currency's purchases out of the calculation.
class ForeignRatesCard extends StatelessWidget {
  const ForeignRatesCard({
    super.key,
    required this.primaryCurrency,
    required this.rates,
  });

  final String primaryCurrency;
  final List<ForeignRateDraft> rates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('foreign-rates-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.foreignRatesTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              S.foreignRatesHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            for (final rate in rates) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (rate.origin != RateOrigin.none)
                    RateOriginBadge(
                      key: Key('foreign-badge-${rate.currency}'),
                      origin: rate.origin,
                    )
                  else
                    Text(
                      S.foreignRateOptional,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: Key('foreign-rate-${rate.currency}'),
                controller: rate.rate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [_decimal],
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                decoration: InputDecoration(
                  labelText: S.howManyIs(primaryCurrency, rate.currency),
                  suffixText: primaryCurrency,
                  errorText: rate.error,
                ),
              ),
              ListenableBuilder(
                listenable: rate.rate,
                builder: (context, _) => rate.willBeExcluded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          S.foreignRateEmptyNote(rate.currency),
                          key: Key('foreign-excluded-${rate.currency}'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
