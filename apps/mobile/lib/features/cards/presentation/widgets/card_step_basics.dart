import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/card_validator.dart';
import '../card_form_controller.dart';
import 'card_step_scaffold.dart';
import 'currency_picker.dart';

/// Step 1: bank, alias, last 4, card currency, optional network, with a
/// live preview of the card. Presentational.
class CardStepBasics extends StatelessWidget {
  const CardStepBasics({
    super.key,
    required this.formKey,
    required this.autovalidate,
    required this.alias,
    required this.bank,
    required this.last4,
    required this.currency,
    required this.network,
    required this.selectedNetwork,
    required this.onPickNetwork,
    required this.onPickOtherNetwork,
    this.userCurrencies = const [],
  });

  final GlobalKey<FormState> formKey;
  final bool autovalidate;
  final TextEditingController alias;
  final TextEditingController bank;
  final TextEditingController last4;
  final TextEditingController currency;
  final TextEditingController network;

  /// A name of [CardFormController.knownNetworks], `other` or null.
  final String? selectedNetwork;
  final ValueChanged<String> onPickNetwork;
  final VoidCallback onPickOtherNetwork;
  final List<String> userCurrencies;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CardStepBody(
      title: l10n.cardStepTitleCard,
      formKey: formKey,
      autovalidate: autovalidate,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: ListenableBuilder(
              listenable: Listenable.merge([alias, last4, currency]),
              builder: (context, _) => CreditCardView(
                key: const Key('card-preview'),
                alias: alias.text.trim().isEmpty
                    ? l10n.cardAliasHint
                    : alias.text.trim(),
                last4: last4.text.trim().padRight(4, '·'),
                currency: currency.text.trim().toUpperCase(),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppField(
          label: l10n.cardNameLabel,
          child: TextFormField(
            key: const Key('field-alias'),
            controller: alias,
            textCapitalization: TextCapitalization.sentences,
            decoration: AppField.decoration(hint: l10n.cardAliasHint),
            validator: CardValidator.required,
          ),
        ),
        cardFieldGap,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 14,
              child: AppField(
                label: l10n.cardBank,
                child: TextFormField(
                  key: const Key('field-bank'),
                  controller: bank,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppField.decoration(),
                  validator: CardValidator.required,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 10,
              child: AppField(
                label: l10n.cardLast4Short,
                child: TextFormField(
                  key: const Key('field-last4'),
                  controller: last4,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontFeatures: appFigures,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: AppField.decoration(),
                  validator: CardValidator.last4,
                ),
              ),
            ),
          ],
        ),
        cardFieldGap,
        AppField(
          label: l10n.cardMainCurrency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('field-currency'),
                controller: currency,
                textCapitalization: TextCapitalization.characters,
                maxLength: 3,
                decoration: AppField.decoration(),
                validator: CardValidator.currency,
              ),
              if (userCurrencies.isNotEmpty) ...[
                const SizedBox(height: 8),
                CurrencyChips(
                  controller: currency,
                  codes: userCurrencies,
                  keyPrefix: 'currency',
                ),
              ],
            ],
          ),
        ),
        cardFieldGap,
        AppField(
          label: l10n.cardNetworkLabel,
          optionalTag: l10n.cardOptionalTag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final n in CardFormController.knownNetworks)
                    AppChip(
                      key: Key('network-$n'),
                      label: n,
                      selected: selectedNetwork == n,
                      onTap: () => onPickNetwork(n),
                    ),
                  AppChip(
                    key: const Key('network-other'),
                    label: l10n.cardNetworkOther,
                    selected: selectedNetwork == 'other',
                    onTap: onPickOtherNetwork,
                  ),
                ],
              ),
              if (selectedNetwork == 'other') ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('field-network'),
                  controller: network,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppField.decoration(
                    hint: l10n.cardNetworkOtherHint,
                  ),
                  validator: (v) => (v ?? '').trim().length > 30
                      ? l10n.fieldTooLong(30)
                      : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
