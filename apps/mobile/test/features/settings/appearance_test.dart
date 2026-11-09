import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/ui/molecules/credit_card_view.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/settings/data/theme_preference_repository_impl.dart';
import 'package:cashback_audit/features/settings/domain/theme_preference.dart';
import 'package:cashback_audit/features/settings/presentation/theme_controller.dart';
import 'package:cashback_audit/features/settings/presentation/widgets/appearance_section.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/transaction_tile.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/verdict_card.dart';
import 'package:cashback_audit/shared/widgets/molecules/inline_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

VerificationTransaction _tx(String source, {String kind = 'PURCHASE'}) =>
    VerificationMapper.detail(
      verificationJson(
        transactions: [
          txJson(
            0,
            'COMERCIO',
            '100',
            source: source,
            credit: false,
            rate: source == 'NONE' ? '1' : '5',
            currency: 'MXN',
            kind: kind,
          ),
        ],
      ),
    ).transactions.single;

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
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const VerdictCard(
                  verdict: Verdict.underpaid,
                  hint: 'hint',
                  expected: r'$58.00',
                  reported: r'$40.00',
                  difference: r'-$18.00',
                ),
                TransactionTile(
                  transaction: _tx('KEYWORD'),
                  currency: 'MXN',
                  unit: RewardUnit.cashbackCurrency,
                ),
                TransactionTile(
                  transaction: _tx('NONE', kind: 'PAYMENT'),
                  currency: 'MXN',
                  unit: RewardUnit.cashbackCurrency,
                ),
                const InlineMessage(
                  message: 'Aviso',
                  tone: InlineMessageTone.warning,
                ),
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
    expect(find.byType(TransactionTile), findsNWidgets(2));
    expect(find.byType(InlineMessage), findsOneWidget);
  });
}
