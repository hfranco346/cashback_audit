import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../cards/presentation/cards_controller.dart';
import '../domain/verification_entities.dart';
import 'history_controller.dart';
import 'widgets/history_view.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  Future<bool> _confirmDelete(VerificationSummary item) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text(S.deleteVerification),
        content: const Text(S.deleteVerificationBody),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Get.back<bool>(result: true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final error = await controller.delete(item);
    if (error != null) Get.snackbar(S.loadError, error);
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
        cardLabel: (id) {
          final c = cards.byId(id);
          return c == null ? '—' : '${c.alias} · ${c.last4}';
        },
        loading: controller.loading.value,
        loadingMore: controller.loadingMore.value,
        hasMore: controller.hasMore.value,
        offline: controller.offline.value,
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onLoadMore: controller.loadMore,
        onOpen: controller.open,
        confirmDelete: _confirmDelete,
      ),
    );
  }
}
