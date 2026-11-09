import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fixtures.dart';

VerificationSummary _summary(
  String id, {
  String status = 'COMPLETED',
  String verdict = 'UNDERPAID',
  String diff = '-18',
  Map<String, dynamic>? card,
  String? failureCode,
}) => VerificationMapper.summary({
  ...summaryJson(id),
  'status': status,
  'card': card ?? {'alias': 'Daily', 'bank': 'BBVA', 'last4': '4321'},
  'failureCode': failureCode,
  if (status != 'COMPLETED') ...{
    'reportedAmount': null,
    'expectedAmount': null,
    'difference': null,
    'verdict': null,
  } else ...{
    'verdict': verdict,
    'difference': diff,
  },
});

Widget _view(
  List<VerificationSummary> items, {
  bool offline = false,
  bool hasMore = false,
  ValueChanged<String?>? onCardFilter,
  VoidCallback? onLoadMore,
  ValueChanged<VerificationSummary>? onOpen,
}) => HistoryView(
  cards: [
    CardMapper.fromJson(cardJson()),
    CardMapper.fromJson(cardJson(id: 'c2', alias: 'Travel')),
  ],
  cardFilter: null,
  onCardFilter: onCardFilter ?? (_) {},
  items: items,
  loading: false,
  loadingMore: false,
  hasMore: hasMore,
  offline: offline,
  onRefresh: () async {},
  onLoadMore: onLoadMore ?? () {},
  onOpen: onOpen ?? (_) {},
  confirmDelete: (_) async => false,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });

  testWidgets('lists pending and completed, filters, opens and paginates', (
    tester,
  ) async {
    String? filter = 'unset';
    var more = 0;
    VerificationSummary? opened;
    await pumpUi(
      tester,
      _view(
        [
          _summary('p', status: 'AWAITING_RATES'),
          _summary('v1'),
          _summary('v2', verdict: 'OVERPAID', diff: '19.32'),
        ],
        hasMore: true,
        onCardFilter: (id) => filter = id,
        onLoadMore: () => more++,
        onOpen: (s) => opened = s,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('PENDIENTES'), findsOneWidget);
    expect(find.text('COMPLETADAS'), findsOneWidget);
    expect(find.text('Confirmar %'), findsOneWidget);
    expect(find.text('Pagaron de menos'), findsOneWidget);
    expect(find.text('Pagaron de más'), findsOneWidget);
    expect(find.text('–MXN 18.00'), findsOneWidget);
    expect(find.textContaining('Daily · 4321'), findsWidgets);
    expect(find.byKey(const Key('history-offline')), findsNothing);
    await tester.tap(find.byKey(const Key('filter-c2')));
    expect(filter, 'c2');
    await tester.tap(find.byKey(const Key('history-row-v1')));
    expect(opened?.id, 'v1');
    await tester.tap(find.byKey(const Key('history-row-p')));
    expect(opened?.id, 'p');
    await tester.ensureVisible(find.byKey(const Key('load-more')));
    await tester.tap(find.byKey(const Key('load-more')));
    expect(more, 1);
  });

  testWidgets('processing and failed entries carry a status pill', (
    tester,
  ) async {
    await pumpUi(
      tester,
      _view([
        _summary('a', status: 'PROCESSING'),
        _summary('b', status: 'FAILED', failureCode: 'NOT_A_STATEMENT'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analizando…'), findsOneWidget);
    expect(find.text('No se pudo analizar'), findsOneWidget);
    expect(find.text('COMPLETADAS'), findsNothing);
  });

  testWidgets('marks entries of a deleted card', (tester) async {
    await pumpUi(
      tester,
      _view([
        _summary(
          'gone',
          card: {
            'alias': 'Old',
            'bank': 'BBVA',
            'last4': '9999',
            'deleted': true,
          },
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old · 9999'), findsOneWidget);
    expect(find.byKey(const Key('deleted-card-gone')), findsOneWidget);
    expect(find.text('Tarjeta eliminada'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await pumpUi(tester, _view(const []));
    await tester.pumpAndSettle();
    expect(find.text('Sin verificaciones todavía'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final lang in ['es', 'en']) {
      testWidgets('offline banner renders (dark=$dark, $lang)', (tester) async {
        await pumpUi(
          tester,
          _view([
            _summary('p', status: 'AWAITING_RATES'),
            _summary('v1'),
          ], offline: true),
          dark: dark,
          lang: lang,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('history-offline')), findsOneWidget);
        expect(
          find.text(lang == 'es' ? 'Historial' : 'History'),
          findsOneWidget,
        );
        expect(
          find.text(lang == 'es' ? 'COMPLETADAS' : 'COMPLETED'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
