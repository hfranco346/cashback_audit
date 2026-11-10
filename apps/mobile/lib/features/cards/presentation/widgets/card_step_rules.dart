import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../../../categories/presentation/widgets/category_picker_sheet.dart';
import '../../domain/card_validator.dart';
import '../card_form_controller.dart';
import 'card_step_scaffold.dart';
import 'rule_editor.dart';

/// Step 3: the base rate and the per-category rules. Presentational.
class CardStepRules extends StatelessWidget {
  const CardStepRules({
    super.key,
    required this.formKey,
    required this.autovalidate,
    required this.baseRate,
    required this.rules,
    required this.categories,
    required this.ruleErrors,
    required this.capSuffix,
    required this.onAddRule,
    required this.onRemoveRule,
    required this.onRuleCategoryChanged,
    required this.onCreateCategory,
  });

  final GlobalKey<FormState> formKey;
  final bool autovalidate;
  final TextEditingController baseRate;
  final List<RuleDraft> rules;
  final List<Category> categories;
  final Map<int, String> ruleErrors;

  /// Unit of each rule's monthly cap, live.
  final String Function() capSuffix;
  final VoidCallback onAddRule;
  final void Function(int) onRemoveRule;
  final void Function(int, String?) onRuleCategoryChanged;
  final CreateCategory onCreateCategory;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CardStepBody(
      title: l10n.cardStepTitleRules,
      formKey: formKey,
      autovalidate: autovalidate,
      children: [
        AppField(
          label: l10n.cardBaseRateLabel,
          help: l10n.cardBaseRateHelp,
          child: TextFormField(
            key: const Key('field-base-rate'),
            controller: baseRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimal],
            style: const TextStyle(
              fontFeatures: appFigures,
              fontWeight: FontWeight.w600,
            ),
            decoration: AppField.decoration(hint: '0', suffix: '%'),
            validator: CardValidator.percent,
          ),
        ),
        cardFieldGap,
        RuleEditor(
          rules: rules,
          categories: categories,
          capSuffix: capSuffix(),
          errors: ruleErrors,
          onAdd: onAddRule,
          onRemove: onRemoveRule,
          onCategoryChanged: onRuleCategoryChanged,
          onCreateCategory: onCreateCategory,
        ),
      ],
    );
  }
}
