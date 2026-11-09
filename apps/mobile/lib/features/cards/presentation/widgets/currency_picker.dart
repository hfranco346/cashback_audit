import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/card_validator.dart';

/// ISO 4217 codes offered as one-tap suggestions after the user's own
/// currencies. Any other 3-letter code can still be typed.
const commonRewardCurrencies = [
  'USD',
  'EUR',
  'MXN',
  'GTQ',
  'HNL',
  'CRC',
  'COP',
  'PEN',
  'CLP',
  'ARS',
  'BRL',
  'DOP',
];

/// The user's own currencies first, then the common ones, without repeats.
List<String> suggestedCurrencies(List<String> userCurrencies, {int max = 6}) {
  final out = <String>[];
  for (final code in [...userCurrencies, ...commonRewardCurrencies]) {
    final c = code.trim().toUpperCase();
    if (c.length == 3 && !out.contains(c)) out.add(c);
    if (out.length == max) break;
  }
  return out;
}

/// Row of one-tap currency chips bound to [controller]. Tapping the selected
/// chip clears it when [clearable] (back to "detect").
class CurrencyChips extends StatelessWidget {
  const CurrencyChips({
    super.key,
    required this.controller,
    required this.codes,
    required this.keyPrefix,
    this.detectLabel,
  });

  final TextEditingController controller;
  final List<String> codes;
  final String keyPrefix;

  /// When set, a leading chip that clears the field ("detect it").
  final String? detectLabel;

  bool get _clearable => detectLabel != null;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final current = value.text.trim().toUpperCase();
        return Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            if (detectLabel != null)
              AppChip(
                key: Key('$keyPrefix-detect'),
                label: detectLabel!,
                selected: current.isEmpty,
                onTap: () => controller.text = '',
              ),
            for (final code in codes)
              AppChip(
                key: Key('$keyPrefix-$code'),
                label: code,
                selected: current == code,
                onTap: () =>
                    controller.text = current == code && _clearable ? '' : code,
              ),
          ],
        );
      },
    );
  }
}

/// Optional "currency the reward is paid in": detect chip, suggestions
/// (user's currencies first) and a free 3-letter entry. Empty means "detect
/// from the statement".
class RewardCurrencyField extends StatelessWidget {
  const RewardCurrencyField({
    super.key,
    required this.controller,
    this.userCurrencies = const [],
  });

  final TextEditingController controller;
  final List<String> userCurrencies;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppField(
      label: l10n.cardRewardCurrencyQuestion,
      help: l10n.cardRewardCurrencyNote,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CurrencyChips(
            controller: controller,
            codes: suggestedCurrencies(userCurrencies, max: 5),
            keyPrefix: 'reward-currency',
            detectLabel: l10n.cardRewardDetect,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('field-reward-currency'),
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            decoration: AppField.decoration(hint: l10n.cardCurrencyOtherHint),
            validator: CardValidator.optionalCurrency,
          ),
        ],
      ),
    );
  }
}
