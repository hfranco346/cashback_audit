import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');
  _registerFontLicenses();
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
