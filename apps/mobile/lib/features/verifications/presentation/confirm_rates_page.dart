import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';
import 'confirm_rates_controller.dart';
import 'period_label.dart';
import 'widgets/confirm_rates_view.dart';
import 'widgets/delete_verification_dialog.dart';
import 'widgets/reward_reporting_card.dart';

/// Container: wires [ConfirmRatesController] to [ConfirmRatesView].
class ConfirmRatesPage extends GetView<ConfirmRatesController> {
  const ConfirmRatesPage({super.key});

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDeleteVerification(
      context,
      creditLost: controller.deleteLosesCreditNote,
    );
    if (!ok) return;
    final error = await controller.deleteVerification();
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Widget? _reportingSection() {
    final proposal = controller.reportingProposal.value;
    if (proposal == null) return null;
    return RewardReportingCard(
      proposal: proposal,
      mode: controller.reportingMode.value,
      onMode: controller.setReportingMode,
      remember: controller.rememberReporting.value,
      onRemember: controller.setRememberReporting,
      previousBalance: controller.previousBalance,
      previousSource: controller.previousBalanceSource.value,
      previousRequired: controller.previousBalanceRequired,
      previousError: controller.previousBalanceError,
      onPreviousTouched: controller.touchPreviousBalance,
      unit: controller.unit,
      currency: controller.rewardDisplayCurrency,
      programName: proposal.programName ?? controller.programName,
      earned: controller.liveEarned,
      onUpload: controller.canUploadPrevious
          ? controller.pickPreviousStatement
          : null,
      uploading: controller.uploadingPrevious.value,
      uploadProgress: controller.previousUploadProgress.value,
      uploadError: controller.previousUploadError.value,
      programChoices: controller.previousProgramChoices.toList(),
      onChooseProgram: controller.choosePreviousProgram,
      busy: controller.submitting.value,
    );
  }

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
        rewardDirection: controller.rewardDirection,
        rewardPreviewAmount: controller.rewardPreviewAmount,
        // Errors show once the user typed or left the field (or the server
        // answered REWARD_EXCHANGE_RATE_REQUIRED).
        rewardRateError:
            controller.rewardRate.text.trim().isNotEmpty ||
                controller.rewardRateTouched
            ? controller.rewardRateError
            : null,
        onRewardRateTouched: controller.touchRewardRate,
        foreignRates: controller.foreignRates.toList(),
        onDelete: controller.canDelete ? () => _delete(context) : null,
        suggestions: controller.suggestions.toList(),
        selectedSuggestions: controller.selectedSuggestions.toSet(),
        onToggleSuggestion: controller.toggleSuggestion,
        onCreateSuggestions: controller.createSuggestedCategories,
        creatingSuggestions: controller.creatingSuggestions.value,
        suggestionsCreated: controller.suggestionsCreatedNotice.value,
        reportingSection: _reportingSection(),
      );
    });
  }
}
