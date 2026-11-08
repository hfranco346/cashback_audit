import 'package:flutter/material.dart';

import '../../../../core/l10n/strings.dart';
import '../../domain/card_validator.dart';

/// ISO 4217 codes offered as one-tap suggestions. Any other 3-letter code can
/// still be typed.
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

/// Optional "currency the reward is paid in": free entry (3 letters) plus
/// one-tap common codes. Empty means "detect from the statement".
class RewardCurrencyField extends StatelessWidget {
  const RewardCurrencyField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const Key('field-reward-currency'),
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: 3,
          decoration: const InputDecoration(
            labelText: S.cardRewardCurrency,
            hintText: S.cardRewardCurrencyAuto,
            helperText: S.cardRewardCurrencyHelper,
            helperMaxLines: 3,
            counterText: '',
          ),
          validator: CardValidator.optionalCurrency,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final current = value.text.trim().toUpperCase();
            return Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                for (final code in commonRewardCurrencies)
                  ChoiceChip(
                    key: Key('reward-currency-$code'),
                    label: Text(code),
                    visualDensity: VisualDensity.compact,
                    selected: current == code,
                    // Tapping the selected code goes back to "detect".
                    onSelected: (on) => controller.text = on ? code : '',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
