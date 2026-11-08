import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../../domain/card_entities.dart';
import '../../domain/card_validator.dart';
import '../card_form_controller.dart';
import 'rule_editor.dart';

/// Pure presentational card form. All state lives in the controller passed
/// by the container page; this widget only lays it out.
class CardFormView extends StatelessWidget {
  const CardFormView({
    super.key,
    required this.formKey,
    required this.alias,
    required this.bank,
    required this.last4,
    required this.network,
    required this.rewardProgram,
    required this.currency,
    required this.pointsFactor,
    required this.baseRate,
    required this.rewardUnit,
    required this.onUnitChanged,
    required this.rules,
    required this.categories,
    required this.ruleErrors,
    required this.onAddRule,
    required this.onRemoveRule,
    required this.onRuleCategoryChanged,
    required this.onSubmit,
    required this.submitting,
    required this.isEditing,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController alias;
  final TextEditingController bank;
  final TextEditingController last4;
  final TextEditingController network;
  final TextEditingController rewardProgram;
  final TextEditingController currency;
  final TextEditingController pointsFactor;
  final TextEditingController baseRate;
  final RewardUnit rewardUnit;
  final ValueChanged<RewardUnit> onUnitChanged;
  final List<RuleDraft> rules;
  final List<Category> categories;
  final Map<int, String> ruleErrors;
  final VoidCallback onAddRule;
  final void Function(int) onRemoveRule;
  final void Function(int, String?) onRuleCategoryChanged;
  final VoidCallback onSubmit;
  final bool submitting;
  final bool isEditing;
  final String? errorMessage;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  @override
  Widget build(BuildContext context) {
    final isPoints = rewardUnit == RewardUnit.points;
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextFormField(
            key: const Key('field-alias'),
            controller: alias,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: S.cardAlias,
              hintText: S.cardAliasHint,
            ),
            validator: CardValidator.required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('field-bank'),
            controller: bank,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: S.cardBank),
            validator: CardValidator.required,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: const Key('field-last4'),
                  controller: last4,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: S.cardLast4,
                    helperText: S.cardLast4Helper,
                    counterText: '',
                  ),
                  validator: CardValidator.last4,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: const Key('field-currency'),
                  controller: currency,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 3,
                  decoration: const InputDecoration(
                    labelText: S.cardCurrency,
                    counterText: '',
                  ),
                  validator: CardValidator.currency,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('field-network'),
            controller: network,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: S.cardNetwork),
            validator: (v) =>
                (v ?? '').trim().length > 30 ? S.fieldTooLong(30) : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('field-reward-program'),
            controller: rewardProgram,
            decoration: const InputDecoration(
              labelText: S.cardRewardProgram,
              helperText: S.cardRewardProgramHelper,
            ),
            validator: (v) =>
                (v ?? '').trim().length > 80 ? S.fieldTooLong(80) : null,
          ),
          const SizedBox(height: 22),
          Text(
            S.rewardUnitLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<RewardUnit>(
            key: const Key('unit-selector'),
            segments: const [
              ButtonSegment(
                value: RewardUnit.cashbackCurrency,
                label: Text(S.unitCashback),
                icon: Icon(Icons.savings_rounded),
              ),
              ButtonSegment(
                value: RewardUnit.points,
                label: Text(S.unitPoints),
                icon: Icon(Icons.stars_rounded),
              ),
            ],
            selected: {rewardUnit},
            onSelectionChanged: (s) => onUnitChanged(s.first),
          ),
          if (isPoints) ...[
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('field-points-factor'),
              controller: pointsFactor,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimal],
              decoration: const InputDecoration(labelText: S.pointsPerUnit),
              validator: CardValidator.pointsFactor,
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            key: const Key('field-base-rate'),
            controller: baseRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimal],
            decoration: const InputDecoration(
              labelText: S.baseRate,
              helperText: S.baseRateHelper,
              suffixText: '%',
            ),
            validator: CardValidator.percent,
          ),
          const SizedBox(height: 26),
          RuleEditor(
            rules: rules,
            categories: categories,
            capSuffix: isPoints ? 'pts' : currency.text.toUpperCase(),
            errors: ruleErrors,
            onAdd: onAddRule,
            onRemove: onRemoveRule,
            onCategoryChanged: onRuleCategoryChanged,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            InlineMessage(message: errorMessage!),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('submit-card'),
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text(S.save),
          ),
        ],
      ),
    );
  }
}
