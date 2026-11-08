import 'package:get/get.dart';
import 'package:flutter/material.dart';

import 'paywall_controller.dart';
import 'widgets/paywall_view.dart';

class PaywallPage extends GetView<PaywallController> {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PaywallView(
        configured: controller.configured,
        subscription: controller.subscriptionPackage,
        packs: controller.packs,
        selectedId: controller.selectedId.value,
        onSelect: controller.select,
        busy: controller.busy.value,
        pending: controller.pending.value,
        freeCredits: controller.credits.balance.value?.free ?? 0,
        errorMessage: controller.errorMessage.value,
        onPurchase: controller.purchase,
        onRestore: controller.restore,
        onCheckAgain: controller.checkAgain,
        onClose: Get.back,
      ),
    );
  }
}
