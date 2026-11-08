import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/session_controller.dart';
import '../../cards/domain/card_entities.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../../shared/widgets/molecules/quick_action_button.dart';
import '../../../core/routing/app_navigator.dart';
import '../../verifications/presentation/history_controller.dart';
import '../../verifications/presentation/verification_navigation.dart';
import '../../verifications/presentation/widgets/latest_verifications_section.dart';
import 'widgets/home_view.dart';

/// Container: wires controllers to the presentational [HomeView].
class HomePage extends GetView<CardsController> {
  const HomePage({super.key});

  Future<void> _confirmDelete(CreditCard card) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text(S.deleteCardTitle),
        content: Text(S.deleteCardBody(card.alias)),
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
    if (ok != true) return;
    final error = await controller.delete(card);
    Get.snackbar(error == null ? S.cardDeleted : S.loadError, error ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    final latest = Get.find<LatestVerificationsController>();
    return Obx(
      () => HomeView(
        greeting: S.greeting(session.user.value?.firstName),
        cards: controller.cards.toList(),
        loading: controller.loading.value,
        offline: controller.offline.value,
        errorMessage: controller.errorMessage.value,
        onRefresh: () async {
          await controller.load();
          await latest.load();
        },
        onAddCard: () => Get.toNamed<void>(Routes.cardForm),
        onOpenCard: (c) => Get.toNamed<void>(Routes.cardForm, arguments: c),
        onLongPressCard: _confirmDelete,
        onOpenCatalog: () => Get.toNamed<void>(Routes.catalog),
        onOpenSettings: () => Get.toNamed<void>(Routes.settings),
        quickActions: [
          QuickActionButton(
            key: const Key('action-verify'),
            icon: Icons.upload_file_rounded,
            label: S.verifyAction,
            primary: true,
            onPressed: () => Get.toNamed<void>(Routes.upload),
          ),
          QuickActionButton(
            key: const Key('action-history'),
            icon: Icons.history_rounded,
            label: S.historyAction,
            onPressed: () => Get.toNamed<void>(Routes.history),
          ),
        ],
        extraSections: [
          LatestVerificationsSection(
            items: latest.items.toList(),
            cardLabel: (id) {
              final c = controller.byId(id);
              return c == null ? '—' : '${c.alias} · ${c.last4}';
            },
            onOpen: (s) => openVerificationSummary(Get.find<AppNavigator>(), s),
            onSeeAll: () => Get.toNamed<void>(Routes.history),
          ),
        ],
      ),
    );
  }
}
