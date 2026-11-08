import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/molecules/inline_message.dart';
import '../../categories/presentation/widgets/merchant_form_sheet.dart';
import '../domain/verification_entities.dart';
import 'result_controller.dart';
import 'widgets/category_picker_sheet.dart';
import 'widgets/verification_result_view.dart';

class ResultPage extends GetView<ResultController> {
  const ResultPage({super.key});

  Future<void> _assign(VerificationTransaction tx) async {
    final catalog = controller.catalog;
    if (catalog.categories.isEmpty) {
      final go = await Get.dialog<bool>(
        AlertDialog(
          title: const Text(S.assignSheetTitle),
          content: const Text(S.noCategoriesToAssign),
          actions: [
            TextButton(
              onPressed: () => Get.back<bool>(result: false),
              child: const Text(S.cancel),
            ),
            FilledButton(
              onPressed: () => Get.back<bool>(result: true),
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              child: const Text(S.goToCategories),
            ),
          ],
        ),
      );
      if (go == true) await Get.toNamed<void>(Routes.catalog);
      return;
    }
    final suggestion = cleanDescriptor(tx.merchant);
    final saved = await Get.bottomSheet<bool>(
      SafeArea(
        child: MerchantFormSheet(
          title: S.assignSheetTitle,
          categories: catalog.categories.toList(),
          initialName: suggestion,
          initialKeywords: [suggestion],
          onSubmit: (name, keywords, categoryId) => controller.assignMerchant(
            tx,
            name: name,
            keywords: keywords,
            categoryId: categoryId,
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Get.theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
    if (saved == true) Get.snackbar(S.merchantAssigned, S.assignedNotice);
  }

  Future<void> _correct(VerificationTransaction tx) async {
    final catalog = controller.catalog;
    if (!catalog.loaded.value) await catalog.load();
    final picked = await Get.bottomSheet<_Pick>(
      CategoryPickerSheet(
        transaction: tx,
        categories: catalog.categories.toList(),
        onPick: (id) => Get.back<_Pick>(result: _Pick(id)),
      ),
      backgroundColor: Get.theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
    if (picked == null) return;
    final message = await controller.correctCategory(tx, picked.categoryId);
    if (message != null) Get.snackbar(S.changeCategory, message);
  }

  Future<void> _retry() async {
    final message = await controller.retryRecalculation();
    if (message != null) Get.snackbar(S.recalcAction, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.resultTitle)),
      body: Obx(() {
        final v = controller.verification.value;
        if (v == null) {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(20),
            child: InlineMessage(
              message: controller.errorMessage.value ?? S.loadError,
              actionLabel: S.retry,
              onAction: controller.load,
            ),
          );
        }
        return VerificationResultView(
          verification: v,
          filter: controller.filter.value,
          onFilterChanged: controller.setFilter,
          assigned: Map.of(controller.assigned),
          onAssign: _assign,
          onCorrect: _correct,
          onRecalculate: controller.recalculateWithOtherRates,
          stale: controller.stale.value,
          recalculating: controller.recalculating.value,
          onRetryRecalculation: _retry,
        );
      }),
    );
  }
}

/// Wrapper so "no category" (null) can be told apart from a dismissed sheet.
class _Pick {
  const _Pick(this.categoryId);
  final String? categoryId;
}
