import 'package:decimal/decimal.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/rate_direction.dart';
import '../../domain/verification_entities.dart'
    show RewardConversion, SuggestedCategory;
import '../confirm_rates_controller.dart';
import 'delete_verification_dialog.dart';
import 'exchange_rate_card.dart';
import 'rate_entry_card.dart';
import 'suggested_categories_card.dart';

/// Pure presentational rate confirmation screen (step 2): every rate with
/// where it came from, the exchange rates that are needed and one footer
/// that says what is still missing.
class ConfirmRatesView extends StatelessWidget {
  const ConfirmRatesView({
    super.key,
    required this.entries,
    required this.capSuffix,
    required this.onTouched,
    required this.saveToCard,
    required this.onSaveToCard,
    required this.canConfirm,
    required this.submitting,
    required this.onConfirm,
    required this.onClose,
    required this.primaryCurrency,
    required this.showExchangeRate,
    required this.exchangeRate,
    required this.foreignExcluded,
    required this.programChoices,
    required this.selectedProgram,
    required this.onSelectProgram,
    required this.needsOverride,
    required this.reportedOverride,
    this.headerLine,
    this.bankName,
    this.programName,
    this.missingFields = const [],
    this.invalidFields = const [],
    this.rewardConversion,
    this.rewardRate,
    this.rewardRateOrigin = RateOrigin.none,
    this.rewardDirection,
    this.rewardPreviewAmount,
    this.rewardRateError,
    this.onRewardRateTouched,
    this.foreignRates = const [],
    this.onDelete,
    this.suggestions = const [],
    this.selectedSuggestions = const {},
    this.onToggleSuggestion,
    this.onCreateSuggestions,
    this.creatingSuggestions = false,
    this.suggestionsCreated = false,
    this.isRecalculation = false,
    this.exchangeRateError,
    this.statementRateNote,
    this.overrideError,
    this.errorMessage,
  });

  final List<RateEntryDraft> entries;
  final String capSuffix;
  final ValueChanged<RateEntryDraft> onTouched;
  final bool saveToCard;
  final ValueChanged<bool> onSaveToCard;
  final bool canConfirm;
  final bool submitting;
  final VoidCallback onConfirm;
  final VoidCallback onClose;
  final bool isRecalculation;

  /// `Ficohsa Signature · Sep 21 – Oct 21, 2026`.
  final String? headerLine;
  final String? bankName;

  /// Program that will be audited, when known.
  final String? programName;

  /// Required fields still empty / filled with an invalid value (footer).
  final List<String> missingFields;
  final List<String> invalidFields;

  final String primaryCurrency;
  final bool showExchangeRate;
  final TextEditingController exchangeRate;
  final String? exchangeRateError;

  /// "Your statement says 1 USD = 26.35 HNL", when the PDF prints a rate.
  final String? statementRateNote;

  /// Foreign purchases exist and no rate is available: they would be left out.
  final bool foreignExcluded;

  final List<String> programChoices;
  final String? selectedProgram;
  final ValueChanged<String?> onSelectProgram;

  final bool needsOverride;
  final TextEditingController reportedOverride;
  final String? overrideError;
  final String? errorMessage;

  /// Reward paid in another currency than the card's (required rate).
  final RewardConversion? rewardConversion;
  final TextEditingController? rewardRate;
  final RateOrigin rewardRateOrigin;
  final RateDirection? rewardDirection;
  final Decimal? rewardPreviewAmount;
  final String? rewardRateError;
  final VoidCallback? onRewardRateTouched;

  /// Optional rate per foreign spend currency.
  final List<ForeignRateDraft> foreignRates;

  /// Opens the delete confirmation (⋮ menu); hidden when null.
  final VoidCallback? onDelete;

  /// Statement categories the user lacks.
  final List<SuggestedCategory> suggestions;
  final Set<String> selectedSuggestions;
  final void Function(String name, bool selected)? onToggleSuggestion;
  final VoidCallback? onCreateSuggestions;
  final bool creatingSuggestions;
  final bool suggestionsCreated;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  String? _footerHint(AppLocalizations l10n) {
    final all = [...missingFields, ...invalidFields];
    if (all.isEmpty) return null;
    if (all.length > 1) return l10n.confirmMissingMany(all.length);
    return missingFields.isNotEmpty
        ? l10n.confirmMissingOne(all.single)
        : l10n.confirmCheckOne(all.single);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hint = canConfirm ? null : _footerHint(l10n);
    final conv = rewardConversion;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('confirm-close'),
          tooltip: l10n.back,
          onPressed: onClose,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        actions: [
          if (onDelete != null) DeleteVerificationMenu(onDelete: onDelete!),
        ],
        title: headerLine == null
            ? null
            : Text(
                headerLine!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: muted,
                  fontFeatures: appFigures,
                ),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  AppSpacing.lg,
                ),
                children: [
                  Text(
                    isRecalculation
                        ? l10n.recalcRatesTitle
                        : l10n.confirmRatesTitle,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeIn(
                    child: Text(
                      l10n.confirmRatesIntro,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (suggestions.isNotEmpty || suggestionsCreated) ...[
                    SuggestedCategoriesCard(
                      suggestions: suggestions,
                      selected: selectedSuggestions,
                      onToggle: onToggleSuggestion ?? (_, _) {},
                      onCreate: onCreateSuggestions ?? () {},
                      creating: creatingSuggestions,
                      createdNotice: suggestionsCreated,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  for (final entry in entries)
                    Padding(
                      key: ValueKey(entry.categoryId ?? 'base'),
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: RateEntryCard(
                        entry: entry,
                        capSuffix: capSuffix,
                        subtitle: entry.isBase ? l10n.rateBaseSubtitle : null,
                        onTouched: () => onTouched(entry),
                      ),
                    ),
                  if (conv != null && rewardRate != null) ...[
                    ExchangeRateCard(
                      key: const Key('reward-conversion-card'),
                      title: l10n.exchangeRewardTitle,
                      body: l10n.exchangeRewardBody(
                        bankName ?? l10n.yourBankFallback,
                        conv.toCurrency,
                        conv.fromCurrency,
                      ),
                      unit: rewardDirection?.unit ?? conv.toCurrency,
                      target: rewardDirection?.quote ?? conv.fromCurrency,
                      direction: rewardDirection,
                      previewAmount: rewardPreviewAmount,
                      previewKind: RatePreviewKind.reward,
                      controller: rewardRate!,
                      fieldKey: const Key('reward-rate-field'),
                      origin: rewardRateOrigin,
                      isRequired: conv.required,
                      error: rewardRateError,
                      onTouched: onRewardRateTouched,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  for (final rate in foreignRates) ...[
                    ExchangeRateCard(
                      key: Key('foreign-rate-card-${rate.currency}'),
                      title: l10n.exchangeForeignTitle(rate.currency),
                      unit: rate.direction.unit,
                      target: rate.direction.quote,
                      direction: rate.direction,
                      previewAmount: rate.previewAmount,
                      controller: rate.rate,
                      fieldKey: Key('foreign-rate-${rate.currency}'),
                      origin: rate.origin,
                      isRequired: false,
                      error: rate.error,
                      emptyNote: l10n.foreignRateEmptyNote(rate.currency),
                      emptyNoteKey: Key('foreign-excluded-${rate.currency}'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (showExchangeRate) ...[
                    ExchangeRateCard(
                      title: l10n.exchangeRateTitle,
                      body: l10n.exchangeRateHelper(primaryCurrency),
                      target: primaryCurrency,
                      controller: exchangeRate,
                      fieldKey: const Key('exchange-rate-field'),
                      origin: RateOrigin.none,
                      isRequired: false,
                      error: exchangeRateError,
                      statementNote: statementRateNote,
                      showFindHint: false,
                    ),
                    if (foreignExcluded) ...[
                      const SizedBox(height: AppSpacing.sm),
                      InlineNotice(
                        key: const Key('exchange-rate-warning'),
                        message: l10n.exchangeRateMissing,
                        kind: StatusKind.warning,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (programChoices.isNotEmpty) ...[
                    _ProgramChooser(
                      choices: programChoices,
                      selected: selectedProgram,
                      onSelected: onSelectProgram,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (needsOverride) ...[
                    Text(
                      l10n.overrideTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    AppField(
                      label: l10n.overrideLabel,
                      help: l10n.overrideHelper,
                      child: TextField(
                        key: const Key('override-field'),
                        controller: reportedOverride,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [_decimal],
                        decoration: AppField.decoration().copyWith(
                          errorText: overrideError,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.saveToCardTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  l10n.saveToCardSubtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            key: const Key('save-to-card'),
                            value: saveToCard,
                            onChanged: submitting ? null : onSaveToCard,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (programName != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      key: const Key('program-audited'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.confirmProgramTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.confirmProgramBody(programName!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InlineNotice(
                      key: const Key('confirm-error'),
                      message: errorMessage!,
                    ),
                  ],
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.md,
                  AppSpacing.screen,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      key: const Key('confirm-button'),
                      label: submitting
                          ? l10n.calculating
                          : l10n.calculateResult,
                      loading: submitting,
                      onPressed: canConfirm ? onConfirm : null,
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        hint,
                        key: const Key('confirm-missing'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.appColors.error.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramChooser extends StatelessWidget {
  const _ProgramChooser({
    required this.choices,
    required this.selected,
    required this.onSelected,
  });

  final List<String> choices;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      key: const Key('program-chooser'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.programChooserTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.programChooserHelper, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: selected,
              onChanged: onSelected,
              child: Column(
                children: [
                  for (final name in choices)
                    RadioListTile<String>(
                      key: Key('program-$name'),
                      contentPadding: EdgeInsets.zero,
                      value: name,
                      title: Text(name),
                    ),
                ],
              ),
            ),
            if (selected == null)
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: context.appColors.error.fg,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.programRequired,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.appColors.error.fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
