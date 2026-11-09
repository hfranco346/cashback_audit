import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../../shared/widgets/molecules/inline_message.dart';
import '../../cards/domain/card_entities.dart';
import 'confirm_rates_controller.dart';
import 'widgets/confirm_rates_view.dart';

/// Container: wires [ConfirmRatesController] to [ConfirmRatesView].
class ConfirmRatesPage extends GetView<ConfirmRatesController> {
  const ConfirmRatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final v = controller.verification.value;
      if (v == null) {
        return Scaffold(
          appBar: AppBar(title: Text(S.confirmRatesTitle)),
          body: controller.loading.value
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: InlineMessage(
                    message:
                        controller.errorMessage.value ?? S.confirmLoadError,
                    actionLabel: S.retry,
                    onAction: controller.fetch,
                  ),
                ),
        );
      }
      final sr = controller.statementRate;
      return ConfirmRatesView(
        isRecalculation: controller.isRecalculation,
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
            : S.exchangeRateStatement(sr.from, sr.to, decimalToApi(sr.rate)),
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
