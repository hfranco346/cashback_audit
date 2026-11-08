import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/home/presentation/widgets/home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

HomeView _view({
  List<CreditCard> cards = const [],
  bool offline = false,
  VoidCallback? onAdd,
  ValueChanged<CreditCard>? onOpen,
}) => HomeView(
  greeting: S.greeting('Ana'),
  cards: cards,
  loading: false,
  offline: offline,
  onRefresh: () async {},
  onAddCard: onAdd ?? () {},
  onOpenCard: onOpen ?? (_) {},
  onLongPressCard: (_) {},
  onOpenCatalog: () {},
  onOpenSettings: () {},
);

void main() {
  Widget wrap(Widget c) => MaterialApp(theme: AppTheme.light, home: c);

  testWidgets('empty state invites adding the first card', (tester) async {
    var added = 0;
    await tester.pumpWidget(wrap(_view(onAdd: () => added++)));
    await tester.pumpAndSettle();
    expect(find.text(S.homeNoCardsTitle), findsOneWidget);
    await tester.tap(find.text(S.addCard));
    expect(added, 1);
  });

  testWidgets('lists cards and shows the offline banner', (tester) async {
    CreditCard? opened;
    await tester.pumpWidget(
      wrap(
        _view(
          cards: [
            CardMapper.fromJson(cardJson()),
            CardMapper.fromJson(cardJson(id: 'c2', alias: 'Travel')),
          ],
          offline: true,
          onOpen: (c) => opened = c,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text(S.offlineBanner), findsOneWidget);
    await tester.tap(find.text('Travel'));
    expect(opened?.id, 'c2');
  });
}
