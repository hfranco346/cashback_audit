import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import 'shell_controller.dart';

/// Bottom navigation of the signed-in app: Home · History · Categories ·
/// Profile (Material 3 [NavigationBar], no FAB). Tabs are built the first
/// time they are visited and kept alive afterwards.
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final ShellController controller;

  /// The four tab bodies, in navigation order. Built lazily.
  final List<WidgetBuilder> tabs;

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  final _visited = <int>{0};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Obx(() {
      final index = widget.controller.tab.value;
      _visited.add(index);
      return Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              _visited.contains(i)
                  ? widget.tabs[i](context)
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: Semantics(
          container: true,
          label: l10n.navAria,
          child: NavigationBar(
            key: const Key('app-navigation-bar'),
            selectedIndex: index,
            onDestinationSelected: widget.controller.select,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n.navHome,
              ),
              NavigationDestination(
                icon: const Icon(Icons.fact_check_outlined),
                selectedIcon: const Icon(Icons.fact_check_rounded),
                label: l10n.navHistory,
              ),
              NavigationDestination(
                icon: const Icon(Icons.sell_outlined),
                selectedIcon: const Icon(Icons.sell_rounded),
                label: l10n.navCategories,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: l10n.navProfile,
              ),
            ],
          ),
        ),
      );
    });
  }
}
