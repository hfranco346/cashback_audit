import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/excluded_reason_text.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/category_picker_sheet.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/verification_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fixtures.dart';

Map<String, dynamic> _bacJson() {
  final json = verificationJson(
    transactions: [
      txJson(
        0,
        'SUPER LA COLONIA',
        '1000',
        source: 'AI_CATEGORY',
        currency: 'HNL',
        reason: 'Supermercado',
      ),
      txJson(1, 'GASOLINERA', '300', source: 'NONE', currency: 'HNL'),
      txJson(
        2,
        'PAGO RECIBIDO',
        '500',
        source: 'NONE',
        currency: 'HNL',
        kind: 'PAYMENT',
      ),
      txJson(
        3,
        'AMAZON',
        '20',
        source: 'NONE',
        currency: 'USD',
        excludedReason: 'NO_EXCHANGE_RATE',
      ),
    ],
  );
  json['primaryCurrency'] = 'HNL';
  json['statement'] = {
    ...json['statement'] as Map<String, dynamic>,
    'currency': 'HNL',
  };
  json['warnings'] = [
    {'code': 'NO_EXCHANGE_RATE', 'message': 'no rate'},
    {'code': 'CARD_LAST4_MISMATCH', 'message': 'mismatch'},
    {'code': 'REPORTED_VALUE_MAY_BE_CUMULATIVE', 'message': 'cumulative'},
    {'code': 'EXPLANATION_UNAVAILABLE', 'message': 'no explanation'},
    {'code': 'SOMETHING_NEW', 'message': 'Texto del servidor'},
  ];
  json['currencies'] = [
    {
      'currency': 'HNL',
      'isPrimary': true,
      'spent': '1300',
      'eligibleSpent': '1300',
      'convertedEligibleSpent': '1300',
      'exchangeRate': null,
      'exchangeRateSource': null,
      'expectedReward': '91',
      'excludedCount': 0,
    },
    {
      'currency': 'USD',
      'isPrimary': false,
      'spent': '20',
      'eligibleSpent': '0',
      'convertedEligibleSpent': null,
      'exchangeRate': null,
      'exchangeRateSource': null,
      'expectedReward': '0',
      'excludedCount': 1,
    },
  ];
  json['loyalty'] = {
    'selectedBy': 'CARD',
    'requestedProgramName': null,
    'selectedProgram': programJson('CASH BAC', '6534'),
    'programs': [
      {
        ...programJson('PUNTOS BAC', '1200'),
        'unit': 'POINTS',
        'available': '900',
      },
      programJson('CASH BAC', '6534'),
    ],
  };
  return json;
}

Widget _host(
  Verification v, {
  TransactionFilter filter = TransactionFilter.all,
  VoidCallback? onRecalculate,
  ValueChanged<VerificationTransaction>? onCorrect,
  bool stale = false,
  VoidCallback? onRetry,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: VerificationResultView(
      verification: v,
      filter: filter,
      onFilterChanged: (_) {},
      assigned: const {},
      onAssign: (_) {},
      onCorrect: onCorrect,
      onRecalculate: onRecalculate,
      stale: stale,
      onRetryRecalculation: onRetry,
    ),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  Future<void> bigSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('shows the explanation, loyalty table and subtotals', (
    tester,
  ) async {
    await bigSurface(tester);
    await tester.pumpWidget(_host(VerificationMapper.detail(_bacJson())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('explanation-card')), findsOneWidget);
    expect(
      find.text('El banco te pago 18 menos de lo esperado.'),
      findsOneWidget,
    );

    // Loyalty: every column, the audited program is highlighted.
    for (final h in [
      S.loyaltyProgram,
      S.loyaltyAccumulated,
      S.loyaltyAvailable,
      S.loyaltyRedeemed,
      S.loyaltyExpiring,
      S.loyaltyForfeited,
    ]) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('PUNTOS BAC'), findsOneWidget);
    expect(find.text('CASH BAC'), findsOneWidget);
    expect(find.byKey(const Key('audited-label')), findsOneWidget);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.map((r) => r.selected), [false, true]);
    expect(find.text('900 pts'), findsOneWidget);
    expect(find.byKey(const Key('cumulative-chip')), findsOneWidget);

    // Per-currency subtotals.
    expect(find.text(S.currenciesTitle), findsOneWidget);
    expect(find.byKey(const Key('currency-HNL')), findsOneWidget);
    expect(find.byKey(const Key('currency-USD')), findsOneWidget);
    expect(find.text(S.currencyExcluded(1)), findsOneWidget);
  });

  testWidgets('warnings are Spanish; unknown codes fall back to the server', (
    tester,
  ) async {
    await bigSurface(tester);
    var recalcs = 0;
    await tester.pumpWidget(
      _host(
        VerificationMapper.detail(_bacJson()),
        onRecalculate: () => recalcs++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.warnNoExchangeRate), findsOneWidget);
    expect(find.text(S.warnLast4), findsOneWidget);
    expect(find.text(S.warnCumulative), findsOneWidget);
    expect(find.text('Texto del servidor'), findsOneWidget);
    // EXPLANATION_UNAVAILABLE carries no value for the user.
    expect(find.text('no explanation'), findsNothing);
    expect(find.text('mismatch'), findsNothing);
    // The missing-rate warning offers the free recalculation.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('warning-NO_EXCHANGE_RATE')),
        matching: find.text(S.recalcAction),
      ),
    );
    expect(recalcs, 1);
  });

  testWidgets('applied rates and the recalculate action', (tester) async {
    await bigSurface(tester);
    var recalcs = 0;
    await tester.pumpWidget(
      _host(
        VerificationMapper.detail(verificationJson()),
        onRecalculate: () => recalcs++,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('applied-rates-card')), findsOneWidget);
    expect(find.text('${S.rateBaseTitle} 1%'), findsOneWidget);
    expect(find.text('Super 5%'), findsOneWidget);
    await tester.tap(find.byKey(const Key('recalculate-button')));
    expect(recalcs, 1);
  });

  testWidgets('mixed transactions: green, red and neutral coexist', (
    tester,
  ) async {
    await bigSurface(tester);
    await tester.pumpWidget(_host(VerificationMapper.detail(_bacJson())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tx-icon-counted')), findsOneWidget);
    expect(find.byKey(const Key('tx-icon-uncounted')), findsOneWidget);
    expect(find.byKey(const Key('tx-icon-excluded')), findsNWidgets(2));
    expect(find.text(S.transactionsSummary(1, 1, 2)), findsOneWidget);
    expect(find.text(S.excludedNoRate('USD')), findsOneWidget);
  });

  testWidgets('stale banner offers a retry', (tester) async {
    await bigSurface(tester);
    var retries = 0;
    await tester.pumpWidget(
      _host(
        VerificationMapper.detail(verificationJson()),
        stale: true,
        onRetry: () => retries++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('stale-banner')),
        matching: find.text(S.recalcAction),
      ),
    );
    expect(retries, 1);
  });

  testWidgets('tapping a counted line reports it for correction', (
    tester,
  ) async {
    await bigSurface(tester);
    VerificationTransaction? tapped;
    await tester.pumpWidget(
      _host(
        VerificationMapper.detail(verificationJson()),
        onCorrect: (t) => tapped = t,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tx-tap-0')));
    expect(tapped?.index, 0);
  });

  testWidgets('category picker returns the chosen id or null', (tester) async {
    final tx = VerificationMapper.detail(verificationJson()).transactions.first;
    final picks = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CategoryPickerSheet(
            transaction: tx,
            categories: const [
              Category(id: 'cat1', name: 'Super'),
              Category(id: 'cat2', name: 'Farmacia'),
            ],
            onPick: picks.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('pick-cat2')));
    await tester.tap(find.byKey(const Key('pick-none')));
    expect(picks, ['cat2', null]);
  });

  test('excluded reasons per kind, in Spanish', () {
    VerificationTransaction t(String kind, {String? reason}) =>
        VerificationMapper.detail(
          verificationJson(
            transactions: [
              txJson(0, 'X', '1', kind: kind, excludedReason: reason),
            ],
          ),
        ).transactions.single;
    expect(excludedReasonText(t('PAYMENT')), S.excludedPayment);
    expect(excludedReasonText(t('FEE')), S.excludedFee);
    expect(excludedReasonText(t('INTEREST')), S.excludedInterest);
    expect(excludedReasonText(t('INSURANCE')), S.excludedInsurance);
    expect(excludedReasonText(t('OTHER')), S.excludedOther);
    expect(excludedReasonText(t('PURCHASE')), isNull);
  });
}
