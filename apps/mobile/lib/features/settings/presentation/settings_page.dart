import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/presentation/session_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../../subscription/presentation/subscription_controller.dart';
import 'locale_controller.dart';
import 'preferences_controller.dart';
import 'theme_controller.dart';
import 'widgets/settings_view.dart';

/// "Perfil" tab: wires [SettingsView] to the app-wide controllers.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _restore(BuildContext context) async {
    final sub = Get.find<SubscriptionController>();
    final credits = Get.find<CreditsController>();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final error = await sub.restorePurchases();
    await credits.fetch();
    messenger.showSnackBar(SnackBar(content: Text(error ?? l10n.restoreDone)));
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionController>();
    final sub = Get.find<SubscriptionController>();
    final credits = Get.find<CreditsController>();
    final themeController = Get.find<ThemeController>();
    final locale = Get.find<LocaleController>();
    final navigator = Get.find<AppNavigator>();
    final prefs = Get.find<PreferencesController>();
    return Obx(() {
      final user = session.user.value;
      final primary = user?.primaryCurrency;
      return SettingsView(
        user: user,
        balance: credits.balance.value,
        subscription: sub.status.value,
        language: locale.preference.value,
        currencies: [
          ?primary,
          for (final c in prefs.currencies)
            if (c.code != primary) c.code,
        ],
        theme: themeController.preference.value,
        onGetMore: () => navigator.push(Routes.paywall),
        onCreditHistory: () => navigator.push(Routes.creditHistory),
        onRestore: () => _restore(context),
        onLanguageCurrencies: () => navigator.push(Routes.languageCurrencies),
        onTheme: themeController.select,
        onSignOut: session.signOut,
      );
    });
  }
}
