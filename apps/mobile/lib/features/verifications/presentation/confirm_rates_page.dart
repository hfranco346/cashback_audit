import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';
import 'confirm_rates_controller.dart';
import 'period_label.dart';
import 'widgets/confirm_rates_view.dart';

/// Container: wires [ConfirmRatesController] to [ConfirmRatesView].
class ConfirmRatesPage extends GetView<ConfirmRatesController> {
  const ConfirmRatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Obx(() {
      final v = controller.verification.value;
      if (v == null) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.back,
              onPressed: Get.back<void>,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: controller.loading.value
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: InlineNotice(
                    message:
                        controller.errorMessage.value ?? l10n.confirmLoadError,
                    actionLabel: l10n.retry,
                    onAction: controller.fetch,
                  ),
                ),
        );
      }
      final sr = controller.statementRate;
      final card = controller.card;
      final period = statementPeriodLabel(v.statement, v.createdAt);
      return ConfirmRatesView(
        isRecalculation: controller.isRecalculation,
        headerLine: card == null ? period : '${card.alias} · $period',
        bankName: v.statement.bank ?? card?.bank,
        programName: controller.programName,
        missingFields: controller.missingFields,
        invalidFields: controller.invalidFields,
        onClose: Get.back<void>,
        entries: controller.entries.toList(),
        capSuffix: controller.unit == RewardUnit.points
            ? 'pts'
            : controller.primaryCurrency,
        onTouched: controller.touch,
        saveToCard: controller.saveToCard.value,
        onSaveToCard: controller.setSaveToCard,
        canConfirm: controller.canConfirm,
        submitting: controller.submitting.value,
        onConfirm: controller.confirm,
        primaryCurrency: controller.primaryCurrency,
        showExchangeRate: controller.showExchangeRate,
        exchangeRate: controller.exchangeRate,
        exchangeRateError: controller.exchangeRateError,
        statementRateNote: sr == null
            ? null
            : l10n.exchangeRateStatement(sr.from, sr.to, decimalToApi(sr.rate)),
        foreignExcluded: controller.foreignWillBeExcluded,
        programChoices: controller.programChoices.toList(),
        selectedProgram: controller.selectedProgram.value,
        onSelectProgram: controller.selectProgram,
        needsOverride: controller.needsReportedOverride.value,
        reportedOverride: controller.reportedOverride,
        overrideError: controller.overrideError,
        errorMessage: controller.errorMessage.value,
        rewardConversion: controller.rewardConversion.value,
        rewardRate: controller.rewardRate,
        rewardRateOrigin: controller.rewardRateOrigin,
        // Errors show once the user typed or left the field (or the server
        // answered REWARD_EXCHANGE_RATE_REQUIRED).
        rewardRateError:
            controller.rewardRate.text.trim().isNotEmpty ||
                controller.rewardRateTouched
            ? controller.rewardRateError
            : null,
        onRewardRateTouched: controller.touchRewardRate,
        foreignRates: controller.foreignRates.toList(),
        suggestions: controller.suggestions.toList(),
        selectedSuggestions: controller.selectedSuggestions.toSet(),
        onToggleSuggestion: controller.toggleSuggestion,
        onCreateSuggestions: controller.createSuggestedCategories,
        creatingSuggestions: controller.creatingSuggestions.value,
        suggestionsCreated: controller.suggestionsCreatedNotice.value,
      );
    });
  }
}
