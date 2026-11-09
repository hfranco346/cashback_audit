import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../categories/presentation/catalog_page.dart';
import '../../home/presentation/home_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../verifications/presentation/history_page.dart';
import 'app_navigation_shell.dart';
import 'shell_controller.dart';

/// `Routes.home`: the shell wired to the real tab screens.
class HomeShellPage extends StatelessWidget {
  const HomeShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNavigationShell(
      controller: Get.find<ShellController>(),
      tabs: [
        (_) => const HomePage(),
        (_) => const HistoryPage(),
        (_) => const CatalogPage(),
        (_) => const SettingsPage(),
      ],
    );
  }
}
