import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../categories/domain/catalog_entities.dart';
import '../../domain/card_entities.dart';
import '../../domain/card_validator.dart';
import '../card_form_controller.dart';
import 'card_preview_band.dart';
import 'currency_picker.dart';
import 'rule_editor.dart';

/// Pure presentational card form. All state lives in the controller passed
/// by the container page; this widget only lays it out: a basic section, a
/// collapsible "advanced options" section and a pinned save button.
class CardFormView extends StatelessWidget {
  const CardFormView({
    super.key,
    required this.formKey,
    required this.alias,
    required this.bank,
    required this.last4,
    required this.network,
    required this.rewardProgram,
    required this.rewardCurrency,
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
    this.rewardReporting = RewardReporting.auto,
    this.onRewardReportingChanged,
    this.advancedOpen = false,
    this.onToggleAdvanced,
    this.selectedNetwork,
    this.onPickNetwork,
    this.onPickOtherNetwork,
    this.userCurrencies = const [],
    this.onDelete,
    this.deleting = false,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController alias;
  final TextEditingController bank;
  final TextEditingController last4;
  final TextEditingController network;
  final TextEditingController rewardProgram;
  final TextEditingController rewardCurrency;
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

  /// How the bank reports the reward figure (advanced section).
  final RewardReporting rewardReporting;
  final ValueChanged<RewardReporting>? onRewardReportingChanged;

  final bool advancedOpen;
  final VoidCallback? onToggleAdvanced;

  /// A name of [CardFormController.knownNetworks], `other` or null.
  final String? selectedNetwork;
  final ValueChanged<String>? onPickNetwork;
  final VoidCallback? onPickOtherNetwork;
  final List<String> userCurrencies;

  /// Shown at the bottom of the advanced section when editing.
  final VoidCallback? onDelete;
  final bool deleting;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isPoints = rewardUnit == RewardUnit.points;
    const gap = SizedBox(height: 14);
    return Column(
      children: [
        Expanded(
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                CardPreviewBand(alias: alias, last4: last4),
                gap,
                SectionHeader(title: l10n.cardBasicCaption, caption: true),
                gap,
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
                gap,
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
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
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
                gap,
                AppField(
                  label: l10n.cardRewardKindQuestion,
                  child: AppSegmented<RewardUnit>(
                    key: const Key('unit-selector'),
                    options: [
                      SegmentOption(
                        value: RewardUnit.cashbackCurrency,
                        label: l10n.cardUnitCashback,
                      ),
                      SegmentOption(
                        value: RewardUnit.points,
                        label: l10n.cardUnitPoints,
                      ),
                    ],
                    selected: rewardUnit,
                    onChanged: onUnitChanged,
                  ),
                ),
                if (isPoints) ...[
                  gap,
                  AppField(
                    label: l10n.pointsPerUnit,
                    child: TextFormField(
                      key: const Key('field-points-factor'),
                      controller: pointsFactor,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimal],
                      decoration: AppField.decoration(),
                      validator: CardValidator.pointsFactor,
                    ),
                  ),
                ],
                gap,
                AppField(
                  label: l10n.cardBaseRateLabel,
                  help: l10n.cardBaseRateHelp,
                  child: TextFormField(
                    key: const Key('field-base-rate'),
                    controller: baseRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_decimal],
                    style: const TextStyle(
                      fontFeatures: appFigures,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: AppField.decoration(hint: '0', suffix: '%'),
                    validator: CardValidator.percent,
                  ),
                ),
                gap,
                ListenableBuilder(
                  listenable: currency,
                  builder: (context, _) => RuleEditor(
                    rules: rules,
                    categories: categories,
                    capSuffix: isPoints ? 'pts' : currency.text.toUpperCase(),
                    errors: ruleErrors,
                    onAdd: onAddRule,
                    onRemove: onRemoveRule,
                    onCategoryChanged: onRuleCategoryChanged,
                  ),
                ),
                gap,
                _AdvancedHeader(open: advancedOpen, onTap: onToggleAdvanced),
                AnimatedSize(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  // Kept mounted while collapsed so the form still validates
                  // its fields.
                  child: Visibility(
                    visible: advancedOpen,
                    maintainState: true,
                    child: _advanced(context, isPoints),
                  ),
                ),
                if (errorMessage != null) ...[
                  gap,
                  InlineNotice(message: errorMessage!),
                ],
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AppButton(
                key: const Key('submit-card'),
                label: l10n.save,
                loading: submitting,
                onPressed: submitting ? null : onSubmit,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _advanced(BuildContext context, bool isPoints) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 14);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        onTap: onPickNetwork == null
                            ? null
                            : () => onPickNetwork!(n),
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
          gap,
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
          gap,
          AppField(
            label: l10n.cardProgramLabel,
            optionalTag: l10n.cardOptionalTag,
            help: l10n.cardProgramHelp,
            child: TextFormField(
              key: const Key('field-reward-program'),
              controller: rewardProgram,
              decoration: AppField.decoration(),
              validator: (v) =>
                  (v ?? '').trim().length > 80 ? l10n.fieldTooLong(80) : null,
            ),
          ),
          if (!isPoints) ...[
            gap,
            RewardCurrencyField(
              controller: rewardCurrency,
              userCurrencies: userCurrencies,
            ),
          ],
          gap,
          _RewardReportingField(
            value: rewardReporting,
            onChanged: onRewardReportingChanged,
          ),
          if (onDelete != null) ...[
            const SizedBox(height: 18),
            Divider(color: scheme.outlineVariant, height: 1),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('delete-card'),
              onPressed: deleting ? null : onDelete,
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.cardDeleteAction),
            ),
            Text(
              l10n.cardDeleteNote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Advanced options" toggle: a bordered row with a hint when collapsed, a
/// plain bold row when expanded (as in the design).
class _AdvancedHeader extends StatelessWidget {
  const _AdvancedHeader({required this.open, required this.onTap});

  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: const Key('advanced-toggle'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: BoxConstraints(minHeight: open ? 48 : 56),
          padding: EdgeInsets.symmetric(horizontal: open ? 4 : 16),
          decoration: BoxDecoration(
            color: open ? Colors.transparent : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: open ? Colors.transparent : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.cardAdvancedTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: open ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    if (!open)
                      Text(
                        l10n.cardAdvancedSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "How does your bank report the cashback?": Auto / earned in the month /
/// accumulated balance, as three self-explaining rows.
class _RewardReportingField extends StatelessWidget {
  const _RewardReportingField({required this.value, required this.onChanged});

  final RewardReporting value;
  final ValueChanged<RewardReporting>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = [
      (
        RewardReporting.auto,
        l10n.cardReportingAuto,
        l10n.cardReportingAutoHint,
      ),
      (
        RewardReporting.monthly,
        l10n.cardReportingMonthly,
        l10n.cardReportingMonthlyHint,
      ),
      (
        RewardReporting.cumulative,
        l10n.cardReportingCumulative,
        l10n.cardReportingCumulativeHint,
      ),
    ];
    return AppField(
      key: const Key('reward-reporting-field'),
      label: l10n.cardReportingLabel,
      optionalTag: l10n.cardOptionalTag,
      help: l10n.cardReportingHelp,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.field),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: RadioGroup<RewardReporting>(
          groupValue: value,
          onChanged: (v) {
            if (v != null) onChanged?.call(v);
          },
          child: Column(
            children: [
              for (final (mode, title, hint) in options)
                RadioListTile<RewardReporting>(
                  key: Key('reporting-${mode.name}'),
                  value: mode,
                  dense: true,
                  title: Text(title),
                  subtitle: Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
