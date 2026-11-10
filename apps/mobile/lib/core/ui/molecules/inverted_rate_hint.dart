import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import '../../theme/app_theme.dart';
import '../../utils/decimal_utils.dart';
import '../../utils/rate_direction.dart';

/// Warning (never blocking) shown under an exchange-rate field when the typed
/// number looks upside down: "Did you mean 1 USD = 26.32 HNL?" with a button
/// that flips it. Renders nothing for a sensible value.
class InvertedRateHint extends StatelessWidget {
  const InvertedRateHint({
    super.key,
    required this.direction,
    required this.shown,
    required this.onUse,
  });

  final RateDirection direction;

  /// What the user typed (the question's direction); `null` when empty.
  final Decimal? shown;

  /// Called with the suggested value.
  final ValueChanged<Decimal> onUse;

  @override
  Widget build(BuildContext context) {
    final value = shown;
    final suggestion = value == null
        ? null
        : direction.invertedSuggestion(value);
    if (suggestion == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.appColors;
    final text = formatExchangeRate(suggestion);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        key: const Key('inverted-rate-hint'),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: colors.warning.bg,
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_vert_rounded, size: 18, color: colors.warning.fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.rateInvertedHint(direction.unit, text, direction.quote),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.warning.fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              key: const Key('inverted-rate-use'),
              onPressed: () => onUse(suggestion),
              child: Text(l10n.rateInvertedUse(text)),
            ),
          ],
        ),
      ),
    );
  }
}
