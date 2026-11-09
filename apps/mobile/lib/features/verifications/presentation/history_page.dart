import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../cards/presentation/cards_controller.dart';
import '../domain/verification_entities.dart';
import 'history_controller.dart';
import 'widgets/history_view.dart';

class HistoryPage extends GetView<HistoryController> {
  const HistoryPage({super.key});

  Future<bool> _confirmDelete(
    BuildContext context,
    VerificationSummary item,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteVerification),
        content: Text(l10n.deleteVerificationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final error = await controller.delete(item);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
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
        errorMessage: controller.errorMessage.value,
        onRefresh: controller.load,
        onLoadMore: controller.loadMore,
        onOpen: controller.open,
        confirmDelete: (item) => _confirmDelete(context, item),
      ),
    );
  }
}
