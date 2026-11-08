import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../../domain/verification_entities.dart';
import '../confirm_rates_controller.dart';
import 'rate_entry_card.dart';

final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

/// Required field shown when the bank pays the reward in another currency
/// than the card's: "¿Cuántos HNL vale 1 USD?".
class RewardConversionCard extends StatelessWidget {
  const RewardConversionCard({
    super.key,
    required this.conversion,
    required this.controller,
    required this.origin,
    required this.onTouched,
    this.error,
  });

  final RewardConversion conversion;
  final TextEditingController controller;
  final RateOrigin origin;
  final VoidCallback onTouched;

  /// Already filtered by the container (shown once the user interacted).
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = conversion.fromCurrency;
    final to = conversion.toCurrency;
    // "Obligatorio" only when there is nothing prefilled and it is required.
    final showBadge = origin != RateOrigin.none || conversion.required;
    return Card(
      key: const Key('reward-conversion-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.currency_exchange_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.rewardConversionTitle(to, from),
                    key: const Key('reward-conversion-title'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              S.rewardConversionHelper(to),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  RateOriginBadge(
                    key: const Key('reward-rate-badge'),
                    origin: origin,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('reward-rate-field'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimal],
              onChanged: (_) => onTouched(),
              onTapOutside: (_) => onTouched(),
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                labelText: S.howManyIs(from, to),
                suffixText: from,
                errorText: error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
