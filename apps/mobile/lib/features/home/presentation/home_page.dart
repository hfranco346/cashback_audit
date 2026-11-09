import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/ui/ui.dart';
import '../../auth/presentation/session_controller.dart';
import '../../cards/domain/card_entities.dart';
import '../../verifications/domain/verification_entities.dart';
import '../../verifications/presentation/failure_text.dart';
import '../../verifications/presentation/verification_navigation.dart';
import '../../navigation/presentation/shell_controller.dart';
import 'home_controller.dart';
import 'widgets/home_view.dart';

/// Container: wires the controllers to the presentational [HomeView]. Lives
/// in the first tab of the navigation shell.
class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  static String greetingFor(BuildContext context, DateTime now, String? name) {
    final l10n = context.l10n;
    final who = name ?? 'none';
    if (now.hour < 12) return l10n.homeGreetingMorning(who);
    if (now.hour < 19) return l10n.homeGreetingAfternoon(who);
    return l10n.homeGreetingEvening(who);
  }

  static String initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
  }

  Future<void> _explainFailure(BuildContext context, VerificationSummary item) {
    final l10n = context.l10n;
    return showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => AppBottomSheet(
        title: l10n.pendingFailedTitle,
        actions: [
          AppButton(
            key: const Key('failure-dismiss'),
            label: l10n.processingDismiss,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        child: Text(
          failureMessage(l10n, item.failureCode),
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final session = Get.find<SessionController>();
    final navigator = Get.find<AppNavigator>();
    return Obx(() {
      final user = session.user.value;
      final cards = c.cards.cards.toList();
      final latest = c.latest.items.toList();
      final balance = c.credits.balance.value;
      return HomeView(
        layout: c.layout,
        greeting: greetingFor(context, DateTime.now(), user?.firstName),
        initials: initialsOf(user?.name ?? user?.email),
        firstName: user?.firstName,
        cards: cards,
        latest: latest,
        pending: c.attention.items.toList(),
        cardLabel: c.cardLabel,
        categoryName: c.categoryName,
        freeChecks: balance?.free,
        totalChecks: balance?.total,
        uncategorized: c.uncategorized.value,
        offline: c.cards.offline.value,
        errorMessage: c.cards.errorMessage.value,
        onRefresh: c.refreshAll,
        onProfile: () => Get.find<ShellController>().select(3),
        onVerify: () {
          c.dismissFresh();
          navigator.push(Routes.upload);
        },
        onAddCard: () {
          c.dismissFresh();
          navigator.push(Routes.cardForm);
        },
        onOpenCard: (CreditCard card) =>
            navigator.push(Routes.cardForm, arguments: card),
        onOpenVerification: (s) => openVerificationSummary(navigator, s),
        onOpenPending: (item) => c.attention.open(
          item,
          showFailure: (i) => _explainFailure(context, i),
        ),
        onSeeAll: () => Get.find<ShellController>().select(1),
        onGetMore: () => navigator.push(Routes.paywall),
        onGuidedSetup: () => navigator.push(Routes.onboarding),
      );
    });
  }
}
