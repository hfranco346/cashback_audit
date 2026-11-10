import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routing/app_navigator.dart';
import 'credit_history_controller.dart';
import 'credits_controller.dart';
import 'widgets/credit_history_view.dart';

class CreditHistoryPage extends GetView<CreditHistoryController> {
  const CreditHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final credits = Get.find<CreditsController>();
    return Obx(
      () => CreditHistoryView(
        items: controller.items.toList(),
        loading: controller.loading.value,
        loadingMore: controller.loadingMore.value,
        hasMore: controller.hasMore.value,
        balance: credits.total,
        unlimited: credits.isUnlimited,
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onLoadMore: controller.loadMore,
        onBack: Get.find<AppNavigator>().pop,
      ),
    );
  }
}
