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
        packages: controller.packages.toList(),
        selectedId: controller.selectedId.value,
        onSelect: controller.select,
        busy: controller.busy.value,
        pending: controller.pending.value,
        errorMessage: controller.errorMessage.value,
        onSubscribe: controller.purchase,
        onRestore: controller.restore,
        onCheckAgain: controller.checkAgain,
        onClose: Get.back,
      ),
    );
  }
}
