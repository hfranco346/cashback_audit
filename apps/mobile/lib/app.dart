import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/di/initial_binding.dart';
import 'core/l10n/strings.dart';
import 'l10n/app_localizations.dart';
import 'core/routing/app_pages.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/locale_controller.dart';
import 'features/settings/presentation/theme_controller.dart';

class CashbackAuditApp extends StatelessWidget {
  const CashbackAuditApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      onGenerateTitle: (_) => S.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Initial mode only; later changes go through Get.changeThemeMode.
      themeMode: Get.find<ThemeController>().themeMode,
      // Initial locale only; later changes go through Get.updateLocale.
      locale: Get.find<LocaleController>().locale,
      fallbackLocale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        // Keeps the legacy `S` layer on the locale Flutter resolved.
        S.bind(context);
        return child ?? const SizedBox.shrink();
      },
      initialBinding: InitialBinding(),
      initialRoute: Routes.splash,
      getPages: AppPages.pages,
    );
  }
}
