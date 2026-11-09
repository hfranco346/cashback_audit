import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/session_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../../credits/presentation/widgets/credits_summary_card.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../subscription/presentation/widgets/subscription_status_card.dart';
import 'theme_controller.dart';
import 'widgets/appearance_section.dart';

/// Profile, subscription and sign-out.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _restore(
    SubscriptionController sub,
    CreditsController credits,
  ) async {
    final error = await sub.restorePurchases();
    await credits.fetch();
    Get.snackbar(error == null ? S.restoreDone : S.loadError, error ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    final sub = Get.find<SubscriptionController>();
    final credits = Get.find<CreditsController>();
    final themeController = Get.find<ThemeController>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Obx(() {
            final user = session.user.value;
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (user?.firstName ?? '?').characters.first.toUpperCase(),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                title: Text(user?.name ?? user?.email ?? ''),
                subtitle: user?.name != null && user?.email != null
                    ? Text(user!.email!)
                    : null,
              ),
            );
          }),
          const SizedBox(height: 20),
          Text(S.creditsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Obx(
            () => CreditsSummaryCard(
              balance: credits.balance.value,
              loading: credits.loading.value,
              onBuy: () => Get.toNamed<void>(Routes.paywall),
              onHistory: () => Get.toNamed<void>(Routes.creditHistory),
            ),
          ),
          const SizedBox(height: 20),
          Text(S.subscriptionTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Obx(
            () => SubscriptionStatusCard(
              status: sub.status.value,
              loading: sub.loading.value,
              onManage: () => Get.toNamed<void>(Routes.paywall),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('restore-purchases'),
            onPressed: () => _restore(sub, credits),
            icon: const Icon(Icons.restore_rounded),
            label: Text(S.paywallRestore),
          ),
          const SizedBox(height: 20),
          Obx(
            () => AppearanceSection(
              selected: themeController.preference.value,
              onChanged: themeController.select,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('logout'),
            onPressed: session.signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(S.logout),
          ),
        ],
      ),
    );
  }
}
