import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../shared/widgets/atoms/staggered_entrance.dart';
import '../../../../shared/widgets/molecules/inline_message.dart';
import '../confirm_rates_controller.dart';
import '../../domain/verification_entities.dart';
import 'foreign_rates_card.dart';
import 'rate_entry_card.dart';
import 'reward_conversion_card.dart';
import 'suggested_categories_card.dart';

/// Pure presentational rate confirmation screen (step 2).
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
    required this.primaryCurrency,
    required this.showExchangeRate,
    required this.exchangeRate,
    required this.foreignExcluded,
    required this.programChoices,
    required this.selectedProgram,
    required this.onSelectProgram,
    required this.needsOverride,
    required this.reportedOverride,
    this.rewardConversion,
    this.rewardRate,
    this.rewardRateOrigin = RateOrigin.none,
    this.rewardRateError,
    this.onRewardRateTouched,
    this.foreignRates = const [],
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
  final bool isRecalculation;

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
  final String? rewardRateError;
  final VoidCallback? onRewardRateTouched;

  /// Optional rate per foreign spend currency.
  final List<ForeignRateDraft> foreignRates;

  /// Statement categories the user lacks.
  final List<SuggestedCategory> suggestions;
  final Set<String> selectedSuggestions;
  final void Function(String name, bool selected)? onToggleSuggestion;
  final VoidCallback? onCreateSuggestions;
  final bool creatingSuggestions;
  final bool suggestionsCreated;

  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var position = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(isRecalculation ? S.recalcRatesTitle : S.confirmRatesTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          FadeIn(
            child: Text(S.confirmRatesIntro, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 6),
          Text(
            S.confirmRatesNoCharge,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (suggestions.isNotEmpty || suggestionsCreated) ...[
            SuggestedCategoriesCard(
              suggestions: suggestions,
              selected: selectedSuggestions,
              onToggle: onToggleSuggestion ?? (_, _) {},
              onCreate: onCreateSuggestions ?? () {},
              creating: creatingSuggestions,
              createdNotice: suggestionsCreated,
            ),
            const SizedBox(height: 12),
          ],
          for (final entry in entries)
            Padding(
              key: ValueKey(entry.categoryId ?? 'base'),
              padding: const EdgeInsets.only(bottom: 12),
              child: StaggeredEntrance(
                index: position++,
                child: RateEntryCard(
                  entry: entry,
                  capSuffix: capSuffix,
                  subtitle: entry.isBase ? S.rateBaseSubtitle : null,
                  onTouched: () => onTouched(entry),
                ),
              ),
            ),
          if (rewardConversion != null && rewardRate != null) ...[
            const SizedBox(height: 4),
            RewardConversionCard(
              conversion: rewardConversion!,
              controller: rewardRate!,
              origin: rewardRateOrigin,
              onTouched: onRewardRateTouched ?? () {},
              error: rewardRateError,
            ),
            const SizedBox(height: 12),
          ],
          if (foreignRates.isNotEmpty) ...[
            const SizedBox(height: 4),
            ForeignRatesCard(
              primaryCurrency: primaryCurrency,
              rates: foreignRates,
            ),
            const SizedBox(height: 12),
          ],
          if (showExchangeRate) ...[
            const SizedBox(height: 4),
            _ExchangeRateSection(
              primaryCurrency: primaryCurrency,
              controller: exchangeRate,
              error: exchangeRateError,
              statementNote: statementRateNote,
              excluded: foreignExcluded,
              decimal: _decimal,
            ),
            const SizedBox(height: 12),
          ],
          if (programChoices.isNotEmpty) ...[
            _ProgramChooser(
              choices: programChoices,
              selected: selectedProgram,
              onSelected: onSelectProgram,
            ),
            const SizedBox(height: 12),
          ],
          if (needsOverride) ...[
            Text(S.overrideTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const Key('override-field'),
              controller: reportedOverride,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimal],
              decoration: InputDecoration(
                labelText: S.overrideLabel,
                helperText: S.overrideHelper,
                helperMaxLines: 2,
                errorText: overrideError,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            key: const Key('save-to-card'),
            contentPadding: EdgeInsets.zero,
            value: saveToCard,
            onChanged: submitting ? null : onSaveToCard,
            title: const Text(S.saveToCardTitle),
            subtitle: const Text(S.saveToCardSubtitle),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            InlineMessage(
              key: const Key('confirm-error'),
              message: errorMessage!,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('confirm-button'),
            onPressed: canConfirm ? onConfirm : null,
            child: submitting
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                      const SizedBox(width: 12),
                      Text(S.calculating),
                    ],
                  )
                : const Text(S.calculateResult),
          ),
        ],
      ),
    );
  }
}

class _ExchangeRateSection extends StatelessWidget {
  const _ExchangeRateSection({
    required this.primaryCurrency,
    required this.controller,
    required this.error,
    required this.statementNote,
    required this.excluded,
    required this.decimal,
  });

  final String primaryCurrency;
  final TextEditingController controller;
  final String? error;
  final String? statementNote;
  final bool excluded;
  final TextInputFormatter decimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.exchangeRateTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              S.exchangeRateHelper(primaryCurrency),
              style: theme.textTheme.bodySmall,
            ),
            if (statementNote != null) ...[
              const SizedBox(height: 8),
              Text(
                statementNote!,
                key: const Key('statement-rate-note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const Key('exchange-rate-field'),
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [decimal],
              decoration: InputDecoration(
                labelText: S.exchangeRateTitle,
                suffixText: primaryCurrency,
                errorText: error,
              ),
            ),
            if (excluded) ...[
              const SizedBox(height: 10),
              const InlineMessage(
                key: Key('exchange-rate-warning'),
                message: S.exchangeRateMissing,
                tone: InlineMessageTone.warning,
              ),
            ],
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
    final theme = Theme.of(context);
    return Card(
      key: const Key('program-chooser'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.programChooserTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(S.programChooserHelper, style: theme.textTheme.bodySmall),
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
              Text(
                S.programRequired,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
