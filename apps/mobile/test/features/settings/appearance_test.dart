import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/ui/ui.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:cashback_audit/features/settings/data/theme_preference_repository_impl.dart';
import 'package:cashback_audit/features/settings/domain/theme_preference.dart';
import 'package:cashback_audit/features/settings/presentation/theme_controller.dart';
import 'package:cashback_audit/features/settings/presentation/widgets/appearance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  testWidgets('segmented control switches the MaterialApp theme mode', (
    tester,
  ) async {
    final controller = ThemeController(
      repository: ThemePreferenceRepositoryImpl(freshPrefs()),
      applyMode: (_) {},
    );
    await tester.pumpWidget(
      Obx(
        () => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: Scaffold(
            body: Obx(
              () => AppearanceSection(
                selected: controller.preference.value,
                onChanged: controller.select,
              ),
            ),
          ),
        ),
      ),
    );
    ThemeMode mode() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
    expect(mode(), ThemeMode.system);
    SegmentedButton<ThemePreference> button() =>
        tester.widget<SegmentedButton<ThemePreference>>(
          find.byType(SegmentedButton<ThemePreference>),
        );
    expect(button().selected, {ThemePreference.system});

    await tester.tap(find.text(S.themeDark));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.dark);
    expect(button().selected, {ThemePreference.dark});

    await tester.tap(find.text(S.themeLight));
    await tester.pumpAndSettle();
    expect(mode(), ThemeMode.light);
  });

  testWidgets('key widgets render under the dark theme without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const VerdictCard(
                  kind: StatusKind.error,
                  statusLabel: 'Pagaron de menos',
                  title: 'Te pagaron de menos',
                  amount: r'-$18.00',
                  expectedLabel: 'Esperado',
                  expected: r'$58.00',
                  reportedLabel: 'Reportado',
                  reported: r'$40.00',
                ),
                const MovementRow(
                  kind: StatusKind.ok,
                  name: 'Comercio',
                  statusText: 'En rubro',
                  amount: r'$100.00',
                ),
                const MovementRow(
                  kind: StatusKind.neutral,
                  name: 'Pago',
                  statusText: 'Excluido',
                  amount: r'$100.00',
                ),
                const InlineNotice(message: 'Aviso', kind: StatusKind.warning),
                const CreditCardView(
                  alias: 'Mi tarjeta',
                  last4: '1234',
                  currency: 'MXN',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(VerdictCard), findsOneWidget);
    expect(find.byType(MovementRow), findsNWidgets(2));
    expect(find.byType(InlineNotice), findsOneWidget);
  });
}
