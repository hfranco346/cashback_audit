import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../cards/presentation/cards_controller.dart';
import '../domain/verification_entities.dart';
import 'history_controller.dart';
import 'widgets/delete_verification_dialog.dart';
import 'widgets/history_view.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  Future<bool> _confirmDelete(
    BuildContext context,
    VerificationSummary item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final ok = await confirmDeleteVerification(
      context,
      creditLost: controller.deleteLosesCreditNote(item),
    );
    if (!ok) return false;
    final error = await controller.delete(item);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? l10n.deleteVerificationDone)),
    );
    return error == null;
  }

  @override
  Widget build(BuildContext context) {
    final cards = Get.find<CardsController>();
    return Obx(
      () => HistoryView(
        cards: cards.cards.toList(),
        cardFilter: controller.cardFilter.value,
        onCardFilter: controller.setCard,
        items: controller.items.toList(),
        loading: controller.loading.value,
        loadingMore: controller.loadingMore.value,
        hasMore: controller.hasMore.value,
        offline: controller.offline.value,
        cachedAt: controller.cachedAt.value,
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onLoadMore: controller.loadMore,
        onOpen: controller.open,
        confirmDelete: (item) => _confirmDelete(context, item),
      ),
    );
  }
}
