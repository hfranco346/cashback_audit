import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import 'card_form_controller.dart';
import 'widgets/card_form_view.dart';
import 'widgets/card_step_basics.dart';
import 'widgets/card_step_review.dart';
import 'widgets/card_step_reward.dart';
import 'widgets/card_step_rules.dart';

/// Container: wires [CardFormController] to the presentational form. Used
/// to create a card and, with a card argument, to edit or delete it.
class CardFormPage extends GetView<CardFormController> {
  const CardFormPage({super.key});

  Future<void> _submit(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final saved = context.l10n.cardSaved;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (await controller.save()) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(saved)));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final card = controller.editing;
    if (card == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCardTitle),
        content: Text(l10n.deleteCardBody(card.alias)),
        actions: [
          TextButton(
            key: const Key('delete-card-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const Key('delete-card-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (await controller.delete()) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.cardDeleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('card-form-close'),
                    tooltip: l10n.cardClose,
                    onPressed: () => Get.back<void>(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        controller.isEditing ? l10n.editCard : l10n.newCard,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final step = controller.step.value;
                // Read inside the builder so the tabs follow `maxStep`.
                controller.maxStep.value;
                return CardFormView(
                  step: step,
                  stepCount: CardFormController.stepCount,
                  canJumpTo: controller.canJumpTo,
                  onJump: controller.goTo,
                  onBack: controller.back,
                  onNext: controller.next,
                  onSubmit: () => _submit(context),
                  submitting: controller.submitting.value,
                  forward: controller.movedForward,
                  child: _stepContent(context, step),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent(BuildContext context, int step) {
    final c = controller;
    final validated = c.validatedSteps.contains(step);
    switch (step) {
      case 0:
        return CardStepBasics(
          formKey: c.stepKeys[0],
          autovalidate: validated,
          alias: c.alias,
          bank: c.bank,
          last4: c.last4,
          currency: c.currency,
          network: c.network,
          selectedNetwork: c.selectedNetwork.value,
          onPickNetwork: c.pickNetwork,
          onPickOtherNetwork: c.pickOtherNetwork,
          userCurrencies: c.userCurrencies,
        );
      case 1:
        return CardStepReward(
          formKey: c.stepKeys[1],
          autovalidate: validated,
          rewardUnit: c.rewardUnit.value,
          onUnitChanged: c.setUnit,
          pointsFactor: c.pointsFactor,
          rewardCurrency: c.rewardCurrency,
          currency: c.currency,
          rewardCap: c.rewardCap,
          capUnit: () => c.capUnit,
          rewardReporting: c.rewardReporting.value,
          onRewardReportingChanged: c.setRewardReporting,
          userCurrencies: c.userCurrencies,
        );
      case 2:
        return CardStepRules(
          formKey: c.stepKeys[2],
          autovalidate: validated,
          baseRate: c.baseRate,
          rules: c.rules.toList(),
          categories: c.catalog.categories.toList(),
          ruleErrors: Map.of(c.ruleErrors),
          capSuffix: () => c.capUnit,
          onAddRule: c.addRule,
          onRemoveRule: c.removeRule,
          onRuleCategoryChanged: c.setRuleCategory,
          onCreateCategory: c.createCategory,
        );
      default:
        return CardStepReview(
          data: c.review(),
          onEditStep: c.goTo,
          errorMessage: c.errorMessage.value,
          onDelete: c.isEditing ? () => _confirmDelete(context) : null,
          deleting: c.deleting.value,
        );
    }
  }
}
