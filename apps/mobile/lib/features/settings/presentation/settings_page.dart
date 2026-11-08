import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/session_controller.dart';
import '../../subscription/presentation/subscription_controller.dart';
import '../../subscription/presentation/widgets/subscription_status_card.dart';

/// Profile, subscription and sign-out.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _restore(SubscriptionController sub) async {
    final error = await sub.restorePurchases();
    Get.snackbar(error == null ? S.restoreDone : S.loadError, error ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    final sub = Get.find<SubscriptionController>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsTitle)),
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
            onPressed: () => _restore(sub),
            icon: const Icon(Icons.restore_rounded),
            label: const Text(S.paywallRestore),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('logout'),
            onPressed: session.signOut,
            icon: const Icon(Icons.logout_rounded),
            label: const Text(S.logout),
          ),
        ],
      ),
    );
  }
}
