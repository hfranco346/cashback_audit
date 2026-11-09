import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/routing/app_navigator.dart';
import '../../cards/presentation/widgets/currency_picker.dart';
import 'preferences_controller.dart';
import 'widgets/currency_sheets.dart';
import 'widgets/language_currencies_view.dart';

/// "Idioma y monedas": wires [LanguageCurrenciesView] to
/// [PreferencesController].
class LanguageCurrenciesPage extends GetView<PreferencesController> {
  const LanguageCurrenciesPage({super.key});

  Future<void> _addCurrency(BuildContext context) async {
    final l10n = context.l10n;
    final taken = {
      ?controller.primaryCurrency,
      for (final c in controller.currencies) c.code,
    };
    final code = await showCurrencyCodeSheet(
      context,
      title: l10n.curAddTitle,
      suggestions: [
        for (final c in suggestedCurrencies(const [], max: 12))
          if (!taken.contains(c)) c,
      ].take(6).toList(),
    );
    if (code == null) return;
    if (code == controller.primaryCurrency) return;
    await controller.addCurrency(code);
  }

  Future<void> _otherPrimary(BuildContext context) async {
    final code = await showCurrencyCodeSheet(
      context,
      title: context.l10n.curSetPrimaryTitle,
    );
    if (code != null) await controller.setPrimaryCurrency(code);
  }

  Future<void> _editRate(BuildContext context, String code) async {
    final primary = controller.primaryCurrency;
    if (primary == null) return;
    final current = controller.currencies
        .firstWhereOrNull((c) => c.code == code)
        ?.rate;
    final result = await showRateSheet(
      context,
      code: code,
      primary: primary,
      current: current,
    );
    if (result == null) return;
    await controller.setRate(code, result.clear ? null : result.rate);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => LanguageCurrenciesView(
        language: controller.languagePreference,
        primary: controller.primaryCurrency,
        currencies: controller.currencies,
        saving: controller.saving.value,
        errorMessage: controller.errorMessage.value,
        languageNotSynced: controller.languageNotSynced.value,
        onLanguage: controller.selectLanguage,
        onPrimary: controller.setPrimaryCurrency,
        onOtherPrimary: () => _otherPrimary(context),
        onAddCurrency: () => _addCurrency(context),
        onRemoveCurrency: controller.removeCurrency,
        onEditRate: (c) => _editRate(context, c.code),
        onBack: Get.find<AppNavigator>().pop,
      ),
    );
  }
}
