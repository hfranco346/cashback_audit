import 'package:flutter/material.dart';

import '../../../../core/l10n/currency_names.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/decimal_utils.dart';
import '../../../cards/presentation/widgets/currency_picker.dart';
import '../../domain/locale_preference.dart';
import '../../domain/user_preferences.dart';
import 'settings_rows.dart';

/// Pure presentational "Idioma y monedas": app language (Automatic /
/// Español / English), main currency and the currencies the user works with
/// (each with its last exchange rate).
class LanguageCurrenciesView extends StatelessWidget {
  const LanguageCurrenciesView({
    super.key,
    required this.language,
    required this.primary,
    required this.currencies,
    required this.saving,
    required this.onLanguage,
    required this.onPrimary,
    required this.onOtherPrimary,
    required this.onAddCurrency,
    required this.onRemoveCurrency,
    required this.onEditRate,
    required this.onBack,
    this.errorMessage,
    this.languageNotSynced = false,
  });

  final LocalePreference language;
  final String? primary;
  final List<CurrencyPref> currencies;
  final bool saving;
  final String? errorMessage;
  final bool languageNotSynced;
  final ValueChanged<LocalePreference> onLanguage;
  final ValueChanged<String> onPrimary;
  final VoidCallback onOtherPrimary;
  final VoidCallback onAddCurrency;
  final ValueChanged<String> onRemoveCurrency;
  final ValueChanged<CurrencyPref> onEditRate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final lang = Localizations.localeOf(context).languageCode;
    final note = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.45,
      color: muted,
    );
    final chips = <String>[
      ?primary,
      for (final c in suggestedCurrencies([
        for (final c in currencies) c.code,
      ], max: 5))
        if (c != primary) c,
    ].take(4).toList();
    final others = [
      for (final c in currencies)
        if (c.code != primary) c,
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('lang-back'),
                    tooltip: l10n.profileBack,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.langScreenTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (saving)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (errorMessage != null) ...[
                    InlineNotice(
                      key: const Key('prefs-error'),
                      message: errorMessage!,
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (languageNotSynced) ...[
                    InlineNotice(
                      key: const Key('prefs-not-synced'),
                      kind: StatusKind.neutral,
                      message: l10n.langSyncFailed,
                    ),
                    const SizedBox(height: 14),
                  ],
                  SectionHeader(title: l10n.langAppLanguage, caption: true),
                  const SizedBox(height: 8),
                  Semantics(
                    container: true,
                    label: l10n.langAppLanguage,
                    child: Column(
                      children: [
                        _LanguageOption(
                          optionKey: 'lang-auto',
                          title: l10n.languageAutomatic,
                          subtitle: l10n.langAutoSubtitle(
                            lang == 'en'
                                ? l10n.languageEnglish
                                : l10n.languageSpanish,
                          ),
                          selected: language == LocalePreference.auto,
                          onTap: () => onLanguage(LocalePreference.auto),
                        ),
                        _LanguageOption(
                          optionKey: 'lang-es',
                          title: l10n.languageSpanish,
                          selected: language == LocalePreference.es,
                          onTap: () => onLanguage(LocalePreference.es),
                        ),
                        _LanguageOption(
                          optionKey: 'lang-en',
                          title: l10n.languageEnglish,
                          selected: language == LocalePreference.en,
                          onTap: () => onLanguage(LocalePreference.en),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.langAutoNote, style: note),
                  const SizedBox(height: 20),
                  SectionHeader(title: l10n.curMain, caption: true),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final code in chips)
                        AppChip(
                          key: Key('primary-$code'),
                          label: code,
                          selected: code == primary,
                          onTap: () => onPrimary(code),
                        ),
                      AppChip(
                        key: const Key('primary-other'),
                        label: l10n.curOther,
                        onTap: onOtherPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.curMainNote, style: note),
                  const SizedBox(height: 20),
                  SectionHeader(title: l10n.curUse, caption: true),
                  const SizedBox(height: 8),
                  SettingsGroup(
                    children: [
                      if (primary != null)
                        _CurrencyRow(
                          key: const Key('currency-primary'),
                          title: currencyTitle(primary!, lang),
                          subtitle: l10n.curMainTag,
                        ),
                      for (final c in others)
                        _CurrencyRow(
                          key: Key('currency-${c.code}'),
                          title: currencyTitle(c.code, lang),
                          subtitle: primary == null
                              ? null
                              : c.rate == null
                              ? l10n.curNoRate
                              : l10n.curLastRate(
                                  c.code,
                                  formatExchangeRate(c.rate!),
                                  primary!,
                                ),
                          onTap: primary == null ? null : () => onEditRate(c),
                          trailing: IconButton(
                            key: Key('remove-${c.code}'),
                            tooltip: l10n.curRemove(c.code),
                            constraints: const BoxConstraints.tightFor(
                              width: 40,
                              height: 40,
                            ),
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            onPressed: () => onRemoveCurrency(c.code),
                          ),
                        ),
                      InkWell(
                        key: const Key('add-currency'),
                        onTap: onAddCurrency,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                l10n.curAdd,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.curUseNote, style: note),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.optionKey,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String optionKey;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        button: true,
        child: InkWell(
          key: Key(optionKey),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  const _CurrencyRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: appFigures,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: appFigures,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}
