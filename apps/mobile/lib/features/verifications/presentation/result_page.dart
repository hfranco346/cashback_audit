import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/ui/ui.dart';
import '../../../core/utils/decimal_utils.dart';

import 'package:decimal/decimal.dart';

import '../domain/verification_entities.dart';
import 'result_controller.dart';
import 'widgets/change_category_sheet.dart';
import 'widgets/verification_result_view.dart';

class ResultPage extends GetView<ResultController> {
  const ResultPage({super.key});

  Future<void> _changeCategory(
    BuildContext context,
    VerificationTransaction tx,
  ) async {
    final catalog = controller.catalog;
    if (!catalog.loaded.value) await catalog.load();
    final v = controller.verification.value;
    if (v == null || !context.mounted) return;
    final applied = v.appliedRates;
    final txCurrency = tx.currency.isEmpty ? v.currency : tx.currency;
    final choice = await showChangeCategorySheet(
      context: context,
      transaction: tx,
      categories: catalog.categories.toList(),
      amountText: formatMoney(tx.signedAmount, currency: txCurrency),
      baseRate: formatRate(applied?.baseRatePercent ?? Decimal.zero),
      rateOf: (id) {
        final rate = applied?.categoryRates
            .where((r) => r.categoryId == id)
            .map((r) => r.ratePercent)
            .firstOrNull;
        return rate == null ? null : formatRate(rate);
      },
      onGoToCategories: () => Get.toNamed<void>(Routes.catalog),
    );
    if (choice == null) return;
    await controller.changeCategory(
      tx,
      choice.categoryId,
      remember: choice.remember,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          final v = controller.verification.value;
          if (v == null) {
            return _Message(
              back: Get.back<void>,
              child: controller.loading.value
                  ? const Center(child: CircularProgressIndicator())
                  : InlineNotice(
                      message: controller.errorMessage.value ?? l10n.loadError,
                      actionLabel: l10n.retry,
                      onAction: controller.load,
                    ),
            );
          }
          if (!v.isCompleted || v.verdict == null || v.reported == null) {
            return _Message(
              back: Get.back<void>,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineNotice(
                    message: l10n.resultNotConfirmed,
                    kind: StatusKind.warning,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    key: const Key('result-confirm'),
                    label: l10n.resultNotConfirmedAction,
                    onPressed: controller.recalculateWithOtherRates,
                  ),
                ],
              ),
            );
          }
          return VerificationResultView(
            verification: v,
            cardLabel: controller.cardLabel,
            tab: controller.tab.value,
            onTab: controller.setTab,
            filter: controller.filter.value,
            onFilterChanged: controller.setFilter,
            onBack: Get.back<void>,
            onChangeCategory: (tx) => _changeCategory(context, tx),
            onRecalculate: controller.recalculateWithOtherRates,
            onClaim: controller.openClaim,
            stale: controller.stale.value,
            recalculating: controller.recalculating.value,
            onRetryRecalculation: controller.retryRecalculation,
            notice: controller.notice.value,
            onDismissNotice: () => controller.notice.value = null,
          );
        }),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.back, required this.child});

  final VoidCallback back;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: context.l10n.back,
            onPressed: back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        Expanded(
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ],
    );
  }
}
