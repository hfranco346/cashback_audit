import 'package:cashback_audit/core/db/app_database.dart';
import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/network/dio_factory.dart';
import 'package:cashback_audit/core/network/session_events.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/data/card_repository_impl.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_adapter.dart';
import '../../support/fixtures.dart';

void main() {
  late AppDatabase db;
  late FakeAdapter adapter;
  late bool offline;

  CardRepositoryImpl repo() => CardRepositoryImpl(
    buildDio(
      baseUrl: 'http://test/api/v1',
      tokens: InMemoryTokenStorage(),
      events: SessionEvents(),
      adapter: adapter,
    ),
    db,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    offline = false;
    adapter = FakeAdapter((o) {
      if (offline) return const FakeResponse(-1);
      if (o.method == 'GET') return FakeResponse(200, [cardJson()]);
      if (o.method == 'DELETE') return const FakeResponse(204);
      return FakeResponse(200, cardJson(id: 'c2', alias: 'New'));
    });
  });
  tearDown(() => db.close());

  test('mapper parses decimals exactly and rules', () {
    final card = CardMapper.fromJson(cardJson());
    expect(card.baseRatePercent, Decimal.parse('1.5'));
    expect(card.rules.single.ratePercent, Decimal.parse('5'));
    expect(card.rules.single.monthlyCap, Decimal.parse('500'));
    expect(card.isPoints, isFalse);
  });

  test('reward currency round-trips and clears on update', () {
    final withReward = CardMapper.fromJson(cardJson(rewardCurrency: 'usd'));
    expect(withReward.rewardCurrency, 'USD');
    expect(
      CardMapper.toRequest(
        withReward.toDraft(),
        forUpdate: false,
      )['rewardCurrency'],
      'USD',
    );
    final none = CardMapper.fromJson(cardJson());
    expect(none.rewardCurrency, isNull);
    final create = CardMapper.toRequest(none.toDraft(), forUpdate: false);
    expect(create.containsKey('rewardCurrency'), isFalse);
    final update = CardMapper.toRequest(none.toDraft(), forUpdate: true);
    expect(update['rewardCurrency'], isNull);
    expect(update.containsKey('rewardCurrency'), isTrue);
    // Cards cached before the field existed still parse.
    final legacy = cardJson()..remove('rewardCurrency');
    expect(CardMapper.fromJson(legacy).rewardCurrency, isNull);
  });

  test('request body: strings for decimals, no points factor for cashback', () {
    final draft = CardMapper.fromJson(cardJson()).toDraft();
    final body = CardMapper.toRequest(draft, forUpdate: false);
    expect(body['baseRatePercent'], '1.5');
    expect(body.containsKey('pointsPerCurrencyUnit'), isFalse);
    expect((body['rules'] as List).single, {
      'categoryId': 'cat1',
      'ratePercent': '5',
      'monthlyCap': '500',
    });
    final points = CardMapper.toRequest(
      CardDraft(
        alias: ' A ',
        bank: 'B',
        last4: '1234',
        rewardUnit: RewardUnit.points,
        pointsPerCurrencyUnit: Decimal.parse('2'),
        baseRatePercent: Decimal.one,
        currency: 'mxn',
      ),
      forUpdate: true,
    );
    expect(points['alias'], 'A');
    expect(points['pointsPerCurrencyUnit'], '2');
    expect(points['currency'], 'MXN');
    expect(points['network'], isNull);
    expect(points.containsKey('network'), isTrue);
  });

  test('rewardProgramName: parsed, sent when set, null clears on update', () {
    final card = CardMapper.fromJson(cardJson(rewardProgramName: 'CASH BAC'));
    expect(card.rewardProgramName, 'CASH BAC');
    expect(CardMapper.fromJson(cardJson()).rewardProgramName, isNull);
    final draft = card.toDraft();
    expect(
      CardMapper.toRequest(draft, forUpdate: false)['rewardProgramName'],
      'CASH BAC',
    );
    final cleared = CardMapper.fromJson(cardJson()).toDraft();
    expect(
      CardMapper.toRequest(
        cleared,
        forUpdate: false,
      ).containsKey('rewardProgramName'),
      isFalse,
    );
    final onUpdate = CardMapper.toRequest(cleared, forUpdate: true);
    expect(onUpdate.containsKey('rewardProgramName'), isTrue);
    expect(onUpdate['rewardProgramName'], isNull);
  });

  test('getCards is network-first and caches', () async {
    final result = await repo().getCards();
    expect(result.fromCache, isFalse);
    expect(result.data.single.alias, 'Daily');
    expect(await db.readCards(), hasLength(1));
  });

  test('getCards serves the cache when offline, errors when empty', () async {
    await expectLater(() {
      offline = true;
      return repo().getCards();
    }(), throwsA(isA<AppException>()));
    offline = false;
    await repo().getCards();
    offline = true;
    final cached = await repo().getCards();
    expect(cached.fromCache, isTrue);
    expect(cached.data.single.id, 'c1');
  });

  test('create/update write through, delete removes from cache', () async {
    final r = repo();
    final draft = CardMapper.fromJson(cardJson()).toDraft();
    final created = await r.createCard(draft);
    expect(created.id, 'c2');
    expect(adapter.requests.last.path, '/cards');
    expect(await db.readCards(), hasLength(1));
    await r.updateCard('c2', draft);
    expect(adapter.requests.last.method, 'PATCH');
    await r.deleteCard('c2');
    expect(await db.readCards(), isEmpty);
  });
}
