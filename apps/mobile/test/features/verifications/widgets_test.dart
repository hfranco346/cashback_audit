import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/history_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('History views', () {
    final cards = [
      CardMapper.fromJson(cardJson()),
      CardMapper.fromJson(cardJson(id: 'c2', alias: 'Travel')),
    ];

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
