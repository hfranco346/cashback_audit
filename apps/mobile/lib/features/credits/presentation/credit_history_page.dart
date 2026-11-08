import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'credit_history_controller.dart';
import 'widgets/credit_history_view.dart';

class CreditHistoryPage extends GetView<CreditHistoryController> {
  const CreditHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => CreditHistoryView(
        items: controller.items.toList(),
        loading: controller.loading.value,
        loadingMore: controller.loadingMore.value,
        hasMore: controller.hasMore.value,
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onLoadMore: controller.loadMore,
      ),
    );
  }
}
