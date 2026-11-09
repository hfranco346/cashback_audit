import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import 'card_form_controller.dart';
import 'widgets/card_form_view.dart';

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
    } else {
      controller.advancedOpen.value = true;
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
              child: FadeInUp(
                from: 12,
                duration: const Duration(milliseconds: 320),
                child: Obx(
                  () => CardFormView(
                    formKey: controller.formKey,
                    alias: controller.alias,
                    bank: controller.bank,
                    last4: controller.last4,
                    network: controller.network,
                    rewardProgram: controller.rewardProgram,
                    rewardCurrency: controller.rewardCurrency,
                    currency: controller.currency,
                    pointsFactor: controller.pointsFactor,
                    baseRate: controller.baseRate,
                    rewardUnit: controller.rewardUnit.value,
                    onUnitChanged: controller.setUnit,
                    rules: controller.rules.toList(),
                    categories: controller.catalog.categories.toList(),
                    ruleErrors: Map.of(controller.ruleErrors),
                    onAddRule: controller.addRule,
                    onRemoveRule: controller.removeRule,
                    onRuleCategoryChanged: controller.setRuleCategory,
                    onSubmit: () => _submit(context),
                    submitting: controller.submitting.value,
                    isEditing: controller.isEditing,
                    errorMessage: controller.errorMessage.value,
                    advancedOpen: controller.advancedOpen.value,
                    onToggleAdvanced: controller.toggleAdvanced,
                    selectedNetwork: controller.selectedNetwork.value,
                    onPickNetwork: controller.pickNetwork,
                    onPickOtherNetwork: controller.pickOtherNetwork,
                    userCurrencies: controller.userCurrencies,
                    onDelete: controller.isEditing
                        ? () => _confirmDelete(context)
                        : null,
                    deleting: controller.deleting.value,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
