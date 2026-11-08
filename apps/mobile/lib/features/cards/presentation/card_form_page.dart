import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import 'card_form_controller.dart';
import 'widgets/card_form_view.dart';
import 'widgets/card_tile.dart';

class CardFormPage extends GetView<CardFormController> {
  const CardFormPage({super.key});

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (await controller.save()) {
      Get.back<void>();
      Get.snackbar(S.cardSaved, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = controller.editing;
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? S.editCard : S.newCard),
      ),
      body: Column(
        children: [
          if (editing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: CardTile(card: editing, onTap: () {}, compact: true),
            ),
          Expanded(
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
                onSubmit: _submit,
                submitting: controller.submitting.value,
                isEditing: controller.isEditing,
                errorMessage: controller.errorMessage.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
