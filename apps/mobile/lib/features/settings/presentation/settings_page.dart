import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/strings.dart';
import '../../auth/presentation/session_controller.dart';

/// Profile and settings. Subscription management is added with the paywall.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
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
