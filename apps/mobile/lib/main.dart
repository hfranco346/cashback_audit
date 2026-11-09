import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/settings/data/locale_preference_repository_impl.dart';
import 'features/settings/data/theme_preference_repository_impl.dart';
import 'features/settings/domain/locale_preference.dart';
import 'features/settings/presentation/locale_controller.dart';
import 'features/settings/domain/theme_preference.dart';
import 'features/settings/presentation/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  await initializeDateFormatting('en_US');
  _registerFontLicenses();
  // Registered before the first frame so the app never flashes the wrong theme.
  final themeRepository = ThemePreferenceRepositoryImpl(
    SharedPreferencesAsync(),
  );
  Get.put<ThemePreferenceRepository>(themeRepository, permanent: true);
  Get.put<ThemeController>(
    ThemeController(
      repository: themeRepository,
      initial: await ThemeController.loadInitial(themeRepository),
    ),
    permanent: true,
  );
  final localeRepository = LocalePreferenceRepositoryImpl(
    SharedPreferencesAsync(),
  );
  Get.put<LocalePreferenceRepository>(localeRepository, permanent: true);
  Get.put<LocaleController>(
    LocaleController(
      repository: localeRepository,
      initial: await LocaleController.loadInitial(localeRepository),
    ),
    permanent: true,
  );
  runApp(const CashbackAuditApp());
}

/// The bundled fonts are OFL-1.1; their license must ship with the app.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Bodoni Moda', 'assets/fonts/OFL-BodoniModa.txt'),
      ('Manrope', 'assets/fonts/OFL-Manrope.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    }
  });
}
