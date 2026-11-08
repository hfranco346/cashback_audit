import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/transaction_tile.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/verification_result_view.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/verification_summary_tile.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fixtures.dart';

Widget _host(Verification v, ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: VerificationResultView(
      verification: v,
      filter: TransactionFilter.all,
      onFilterChanged: (_) {},
      assigned: const {},
      onAssign: (_) {},
      onRecalculate: () {},
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  Future<void> bigSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 4500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  final fico = VerificationMapper.detail(ficohsaCompletedJson());

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('result when the reward currency differs ($name)', () {
      testWidgets('verdict figures are in the reward currency', (tester) async {
        await bigSurface(tester);
        await tester.pumpWidget(_host(fico, theme));
        await tester.pumpAndSettle();
        expect(find.text('USD 22.68'), findsOneWidget); // expected
        expect(find.text('USD 42.00'), findsWidgets); // reported
        expect(find.text('+USD 19.32'), findsOneWidget); // overpaid
        // The card-currency figure is a secondary line.
        expect(
          find.descendant(
            of: find.byKey(const Key('verdict-card')),
            matching: find.text('Equivale a HNL 589.61'),
          ),
          findsOneWidget,
        );
        // Breakdown stays in the card currency (computed before conversion).
        expect(find.textContaining('HNL 1,100.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shows the applied reward exchange rate', (tester) async {
        await bigSurface(tester);
        await tester.pumpWidget(_host(fico, theme));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('reward-rate-detail')),
            matching: find.text('1 USD = 25.9969 HNL'),
          ),
          findsOneWidget,
        );
        expect(find.text(S.rewardRateUserEntered), findsOneWidget);
        expect(find.text(S.rewardRateDetailTitle), findsOneWidget);
      });

      testWidgets('credit lines are labelled by creditType', (tester) async {
        await bigSurface(tester);
        await tester.pumpWidget(_host(fico, theme));
        await tester.pumpAndSettle();
        Finder credit(int i) => find.byKey(Key('tx-credit-$i'));
        expect(tester.widget<Text>(credit(2)).data, 'Pago a la tarjeta');
        expect(tester.widget<Text>(credit(3)).data, 'Devolución');
        expect(
          tester.widget<Text>(credit(4)).data,
          'Otro crédito / bonificación',
        );
        // Charges carry no credit label; a payment is never a refund.
        expect(credit(0), findsNothing);
        expect(find.text('Reembolso'), findsNothing);
        expect(find.text('Devolución'), findsOneWidget);
      });

      testWidgets('Spanish matchReason and the bank hint show', (tester) async {
        await bigSurface(tester);
        await tester.pumpWidget(_host(fico, theme));
        await tester.pumpAndSettle();
        expect(find.text('Supermercado de la zona'), findsOneWidget);
        expect(
          find.text('Tu banco lo considera: Restaurantes y Comida rápida'),
          findsOneWidget,
        );
        // Only the uncategorized line carries the hint.
        expect(find.byKey(const Key('tx-hint-1')), findsOneWidget);
        expect(find.byKey(const Key('tx-hint-0')), findsNothing);
      });

      testWidgets('loyalty amounts use the program currency', (tester) async {
        await bigSurface(tester);
        await tester.pumpWidget(_host(fico, theme));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const Key('loyalty-table')),
            matching: find.text('USD 42.00'),
          ),
          findsOneWidget,
        );
      });
    });
  }

  testWidgets('no "Equivale a" line and no rate detail when currencies match', (
    tester,
  ) async {
    await bigSurface(tester);
    await tester.pumpWidget(
      _host(VerificationMapper.detail(verificationJson()), AppTheme.light),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('expected-equivalent')), findsNothing);
    expect(find.byKey(const Key('reward-rate-detail')), findsNothing);
    expect(find.text('MXN 58.00'), findsWidgets);
  });

  testWidgets('a hint disappears once the line has a category', (tester) async {
    final tx = VerificationMapper.detail(
      verificationJson(
        transactions: [
          txJson(
            0,
            'PIZZA',
            '10',
            source: 'USER',
            suggestedHint: 'Restaurantes y Comida rápida',
          ),
        ],
      ),
    ).transactions.single;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: TransactionTile(
            transaction: tx,
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('tx-hint-0')), findsNothing);
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('history tile shows the reward currency ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: VerificationSummaryTile(
              summary: VerificationMapper.summary(
                VerificationMapper.summaryJsonFromDetail(
                  ficohsaCompletedJson(),
                ),
              ),
              cardLabel: 'Ficohsa · 4321',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('USD 19.32'), findsOneWidget);
      expect(find.textContaining('USD 22.68'), findsOneWidget);
    });
  }
}
