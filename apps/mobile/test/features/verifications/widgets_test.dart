import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/upload_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/history_view.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/transaction_tile.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/transactions_section.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/upload_view.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/verdict_card.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/verification_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fixtures.dart';

VerificationTransaction _tx(
  int index,
  String source, {
  bool credit = false,
  String amount = '100',
  String currency = 'MXN',
  String kind = 'PURCHASE',
  String? excludedReason,
  String? reason,
}) => VerificationMapper.detail(
  verificationJson(
    transactions: [
      txJson(
        index,
        'COMERCIO $index',
        amount,
        source: source,
        credit: credit,
        rate: source == 'NONE' ? '1' : '5',
        currency: currency,
        kind: kind,
        excludedReason: excludedReason,
        reason: reason,
      ),
    ],
  ),
).transactions.single;

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('TransactionTile', () {
    testWidgets('counted: green check, label, category and applied rate', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(0, 'KEYWORD'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
        ),
      );
      expect(find.byKey(const Key('tx-icon-counted')), findsOneWidget);
      expect(find.byKey(const Key('tx-icon-uncounted')), findsNothing);
      expect(find.text(S.countedLabel), findsOneWidget);
      expect(find.text('Super'), findsOneWidget);
      expect(find.text(S.appliedRate('5%')), findsOneWidget);
      expect(find.byKey(const Key('ai-chip-0')), findsNothing);
      expect(find.byKey(const Key('assign-0')), findsNothing);
      final icon = tester.widget<Icon>(
        find.byKey(const Key('tx-icon-counted')),
      );
      expect(icon.color, StatusColors.light.success);
    });

    testWidgets('AI match shows the IA chip and the reason as subtitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(4, 'AI_CATEGORY', reason: 'Es un supermercado'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
        ),
      );
      expect(find.byKey(const Key('ai-chip-4')), findsOneWidget);
      expect(find.byKey(const Key('tx-reason-4')), findsOneWidget);
      expect(find.text('Es un supermercado'), findsOneWidget);
    });

    testWidgets('user-corrected lines show the user chip, not the IA chip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(5, 'USER'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
        ),
      );
      expect(find.byKey(const Key('user-chip-5')), findsOneWidget);
      expect(find.byKey(const Key('ai-chip-5')), findsNothing);
      expect(find.byKey(const Key('tx-icon-counted')), findsOneWidget);
    });

    testWidgets('excluded lines are neutral grey with the Spanish reason', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TransactionTile(
                transaction: _tx(0, 'NONE', kind: 'PAYMENT'),
                currency: 'MXN',
                unit: RewardUnit.cashbackCurrency,
                onAssign: () {},
                onTap: () {},
              ),
              TransactionTile(
                transaction: _tx(
                  1,
                  'NONE',
                  currency: 'USD',
                  excludedReason: 'NO_EXCHANGE_RATE',
                ),
                currency: 'MXN',
                unit: RewardUnit.cashbackCurrency,
              ),
              TransactionTile(
                transaction: _tx(2, 'NONE', kind: 'INSURANCE'),
                currency: 'MXN',
                unit: RewardUnit.cashbackCurrency,
              ),
            ],
          ),
        ),
      );
      // Neither green nor red.
      expect(find.byKey(const Key('tx-icon-counted')), findsNothing);
      expect(find.byKey(const Key('tx-icon-uncounted')), findsNothing);
      expect(find.byKey(const Key('tx-icon-excluded')), findsNWidgets(3));
      final icon = tester.widget<Icon>(
        find.byKey(const Key('tx-icon-excluded')).first,
      );
      expect(icon.color, StatusColors.light.neutral);
      expect(icon.color, isNot(StatusColors.light.danger));
      expect(icon.color, isNot(StatusColors.light.success));
      expect(find.text(S.excludedLabel), findsNWidgets(3));
      expect(find.text(S.excludedPayment), findsOneWidget);
      expect(find.text(S.excludedNoRate('USD')), findsOneWidget);
      expect(find.text(S.excludedInsurance), findsOneWidget);
      // No "assign" action and no rate on excluded lines.
      expect(find.byKey(const Key('assign-0')), findsNothing);
      expect(find.byKey(const Key('tx-rate-0')), findsNothing);
    });

    testWidgets('foreign counted lines show the converted amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(0, 'AI_CATEGORY', currency: 'USD', amount: '10'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
        ),
      );
      expect(find.text('USD 10.00'), findsOneWidget);
      expect(find.byKey(const Key('tx-converted-0')), findsOneWidget);
    });

    testWidgets('tapping a counted line asks to change its category', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(0, 'KEYWORD'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('tx-tap-0')));
      expect(taps, 1);
    });

    testWidgets('AI match shows the IA chip', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(3, 'AI'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
        ),
      );
      expect(find.byKey(const Key('ai-chip-3')), findsOneWidget);
      expect(find.text(S.aiChip), findsOneWidget);
      expect(find.text(S.countedLabel), findsOneWidget);
    });

    testWidgets('not counted: red cross, label, base rate and assign action', (
      tester,
    ) async {
      var assigned = 0;
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(1, 'NONE'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
            onAssign: () => assigned++,
          ),
        ),
      );
      expect(find.byKey(const Key('tx-icon-uncounted')), findsOneWidget);
      expect(find.text(S.uncountedLabel), findsOneWidget);
      expect(find.text('${S.baseOnly} 1%'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byKey(const Key('tx-icon-uncounted')),
      );
      expect(icon.color, StatusColors.light.danger);
      await tester.tap(find.byKey(const Key('assign-1')));
      expect(assigned, 1);
    });

    testWidgets('assigned lines replace the action with a note', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(1, 'NONE'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
            assignedCategory: 'Super',
            onAssign: () {},
          ),
        ),
      );
      expect(find.byKey(const Key('assign-1')), findsNothing);
      expect(find.text(S.assignedTo('Super')), findsOneWidget);
    });

    testWidgets('refunds keep their status color but show a negative amount', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TransactionTile(
                transaction: _tx(0, 'KEYWORD', credit: true, amount: '58'),
                currency: 'MXN',
                unit: RewardUnit.cashbackCurrency,
              ),
              TransactionTile(
                transaction: _tx(1, 'NONE', credit: true, amount: '20'),
                currency: 'MXN',
                unit: RewardUnit.cashbackCurrency,
              ),
            ],
          ),
        ),
      );
      expect(find.text('-MXN 58.00'), findsOneWidget);
      expect(find.text('-MXN 20.00'), findsOneWidget);
      expect(find.byKey(const Key('tx-icon-counted')), findsOneWidget);
      expect(find.byKey(const Key('tx-icon-uncounted')), findsOneWidget);
      expect(find.text(S.refund), findsNWidgets(2));
    });

    testWidgets('dark theme uses the dark semantic colors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            transaction: _tx(1, 'NONE'),
            currency: 'MXN',
            unit: RewardUnit.cashbackCurrency,
          ),
          theme: AppTheme.dark,
        ),
      );
      final icon = tester.widget<Icon>(
        find.byKey(const Key('tx-icon-uncounted')),
      );
      expect(icon.color, StatusColors.dark.danger);
    });
  });

  group('TransactionsSection filter', () {
    final txs = [
      _tx(0, 'KEYWORD'),
      _tx(1, 'AI_CATEGORY'),
      _tx(2, 'NONE'),
      _tx(3, 'NONE'),
      _tx(4, 'NONE'),
      _tx(5, 'NONE', kind: 'PAYMENT'),
      _tx(6, 'NONE', currency: 'USD', excludedReason: 'NO_EXCHANGE_RATE'),
    ];

    Widget host() => _wrap(
      SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setState) {
            var filter = TransactionFilter.all;
            return StatefulBuilder(
              builder: (context, setInner) => TransactionsSection(
                transactions: txs,
                filter: filter,
                onFilterChanged: (f) => setInner(() => filter = f),
                currency: 'MXN',
                unit: RewardUnit.cashbackCurrency,
              ),
            );
          },
        ),
      ),
    );

    testWidgets('shows summary and counts, filters the list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host());
      expect(find.text(S.transactionsSummary(2, 3, 2)), findsOneWidget);
      expect(find.text(S.filterWithCount(S.filterAll, 7)), findsOneWidget);
      expect(find.text(S.filterWithCount(S.filterCounted, 2)), findsOneWidget);
      expect(
        find.text(S.filterWithCount(S.filterUncounted, 3)),
        findsOneWidget,
      );
      expect(find.text(S.filterWithCount(S.filterExcluded, 2)), findsOneWidget);
      expect(find.byType(TransactionTile), findsNWidgets(7));

      await tester.tap(find.text(S.filterWithCount(S.filterCounted, 2)));
      await tester.pump();
      expect(find.byType(TransactionTile), findsNWidgets(2));
      expect(find.byKey(const Key('tx-icon-uncounted')), findsNothing);
      expect(find.byKey(const Key('tx-icon-excluded')), findsNothing);

      await tester.tap(find.text(S.filterWithCount(S.filterUncounted, 3)));
      await tester.pump();
      expect(find.byType(TransactionTile), findsNWidgets(3));
      expect(find.byKey(const Key('tx-icon-counted')), findsNothing);
      expect(find.byKey(const Key('tx-icon-excluded')), findsNothing);

      await tester.tap(find.text(S.filterWithCount(S.filterExcluded, 2)));
      await tester.pump();
      expect(find.byType(TransactionTile), findsNWidgets(2));
      expect(find.byKey(const Key('tx-icon-excluded')), findsNWidgets(2));
      expect(find.byKey(const Key('tx-icon-uncounted')), findsNothing);

      await tester.tap(find.text(S.filterWithCount(S.filterAll, 7)));
      await tester.pump();
      expect(find.byType(TransactionTile), findsNWidgets(7));
    });
  });

  group('VerdictCard / result view', () {
    testWidgets('verdict figures fit a narrow phone without overlapping', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          const VerdictCard(
            verdict: Verdict.underpaid,
            hint: 'hint',
            expected: 'HNL 1,526,184.84',
            reported: 'HNL 0.00',
            reportedLabel: 'CASH BAC CREDOMATIC',
            difference: '-HNL 1,526,184.84',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final expected = tester.getRect(find.text('HNL 1,526,184.84'));
      final reported = tester.getRect(find.text('HNL 0.00'));
      // Stacked rows: the reported amount sits below the expected one and
      // both are right-aligned.
      expect(reported.top, greaterThan(expected.bottom));
      expect((reported.right - expected.right).abs(), lessThan(1));
      expect(find.text('CASH BAC CREDOMATIC'), findsOneWidget);
    });

    testWidgets('verdict card shows label and figures', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VerdictCard(
            verdict: Verdict.underpaid,
            hint: 'hint',
            expected: r'$58.00',
            reported: r'$40.00',
            difference: r'-$18.00',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.verdictUnderpaid), findsOneWidget);
      expect(find.text(r'-$18.00'), findsOneWidget);
    });

    testWidgets(
      'full result: verdict, warning, breakdown and assign callback',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        VerificationTransaction? assigned;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: VerificationResultView(
                verification: VerificationMapper.detail(verificationJson()),
                filter: TransactionFilter.all,
                onFilterChanged: (_) {},
                assigned: const {},
                onAssign: (t) => assigned = t,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(S.verdictUnderpaid), findsOneWidget);
        // Warnings are shown in Spanish, not with the server's English text.
        expect(find.text(S.warnAiUnavailable), findsOneWidget);
        expect(find.text('AI matching failed'), findsNothing);
        expect(find.byKey(const Key('explanation-card')), findsOneWidget);
        expect(find.byKey(const Key('applied-rates-card')), findsOneWidget);
        expect(find.text('Super · 5%'), findsOneWidget);
        expect(find.text('${S.baseRateLine} · 1%'), findsOneWidget);
        await tester.tap(find.byKey(const Key('assign-1')));
        expect(assigned?.index, 1);
      },
    );
  });

  group('Upload / history views', () {
    final cards = [
      CardMapper.fromJson(cardJson()),
      CardMapper.fromJson(cardJson(id: 'c2', alias: 'Travel')),
    ];

    UploadView upload({
      UploadPhase phase = UploadPhase.idle,
      PickedPdf? file,
      bool canSubmit = false,
      List<CreditCard>? list,
      VoidCallback? onSubmit,
      ValueChanged<String>? onSelect,
    }) => UploadView(
      cards: list ?? cards,
      selectedCardId: 'c1',
      onSelectCard: onSelect ?? (_) {},
      file: file,
      onPick: () {},
      phase: phase,
      progress: 0.4,
      canSubmit: canSubmit,
      onSubmit: onSubmit ?? () {},
      onAddCard: () {},
    );

    testWidgets('verify is disabled until a file is picked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: upload()),
      );
      final btn = tester.widget<FilledButton>(
        find.byKey(const Key('verify-button')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows file, card chips and submit', (tester) async {
      var submitted = 0;
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: upload(
            file: const PickedPdf(name: 'edo.pdf', path: '/x', sizeBytes: 2048),
            canSubmit: true,
            onSubmit: () => submitted++,
            onSelect: (id) => selected = id,
          ),
        ),
      );
      expect(find.text('edo.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const Key('card-chip-c2')));
      expect(selected, 'c2');
      await tester.tap(find.byKey(const Key('verify-button')));
      expect(submitted, 1);
    });

    testWidgets('progress overlay shows phases', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: upload(phase: UploadPhase.uploading),
        ),
      );
      expect(find.text(S.uploading), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('upload-progress')),
      );
      expect(bar.value, 0.4);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: upload(phase: UploadPhase.analyzing),
        ),
      );
      expect(find.text(S.analyzing), findsOneWidget);
      // The analyzing state sets expectations with its steps.
      expect(find.byKey(const Key('analyzing-progress')), findsOneWidget);
      expect(find.text(S.analyzingStepRead), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('upload-progress')),
            )
            .value,
        isNull,
      );
    });

    testWidgets('empty cards show the add-card CTA', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: upload(list: const []),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.noCardsForUpload), findsOneWidget);
    });

    testWidgets('history lists items, filters by card and loads more', (
      tester,
    ) async {
      String? filter = 'unset';
      var more = 0;
      VerificationSummary? opened;
      final item = VerificationMapper.summary(summaryJson('v1'));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HistoryView(
            cards: cards,
            cardFilter: null,
            onCardFilter: (id) => filter = id,
            items: [item],
            cardLabel: (_) => 'Daily · 4321',
            loading: false,
            loadingMore: false,
            hasMore: true,
            offline: false,
            onRefresh: () async {},
            onLoadMore: () => more++,
            onOpen: (s) => opened = s,
            confirmDelete: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.verdictUnderpaid), findsOneWidget);
      await tester.tap(find.byKey(const Key('filter-c2')));
      expect(filter, 'c2');
      await tester.tap(find.text(S.verdictUnderpaid));
      expect(opened?.id, 'v1');
      await tester.ensureVisible(find.byKey(const Key('load-more')));
      await tester.tap(find.byKey(const Key('load-more')));
      expect(more, 1);
    });

    testWidgets('history empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HistoryView(
            cards: cards,
            cardFilter: null,
            onCardFilter: (_) {},
            items: const [],
            cardLabel: (_) => '',
            loading: false,
            loadingMore: false,
            hasMore: false,
            offline: false,
            onRefresh: () async {},
            onLoadMore: () {},
            onOpen: (_) {},
            confirmDelete: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(S.historyEmptyTitle), findsOneWidget);
    });
  });
}
