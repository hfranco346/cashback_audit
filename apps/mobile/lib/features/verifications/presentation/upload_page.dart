import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routing/app_routes.dart';
import 'upload_controller.dart';
import 'widgets/upload_view.dart';

class UploadPage extends GetView<UploadController> {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => UploadView(
        cards: controller.cards.cards.toList(),
        selectedCardId: controller.cardId.value,
        onSelectCard: controller.selectCard,
        file: controller.file.value,
        onPick: controller.pickFile,
        phase: controller.phase.value,
        progress: controller.progress.value,
        canSubmit: controller.canSubmit,
        onSubmit: controller.submit,
        onAddCard: () => Get.toNamed<void>(Routes.cardForm),
        needsOverride: controller.needsOverride.value,
        overrideController: controller.overrideText,
        overrideError: controller.overrideError.value,
        errorMessage: controller.errorMessage.value,
      ),
    );
  }
}
