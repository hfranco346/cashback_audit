import 'package:cashback_audit/core/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _card(String id) => {'id': id, 'alias': id};
Map<String, dynamic> _summary(String id, String cardId, String at) => {
  'id': id,
  'cardId': cardId,
  'createdAt': at,
};

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('cards keep order and upsert preserves position', () async {
    await db.replaceCards([_card('a'), _card('b')]);
    await db.upsertCard({'id': 'a', 'alias': 'changed'});
    await db.upsertCard(_card('c'));
    final cards = await db.readCards();
    expect(cards.map((c) => c['id']), ['a', 'b', 'c']);
    expect(cards.first['alias'], 'changed');
  });

  test('removing a card removes its cached verifications', () async {
    await db.replaceCards([_card('a'), _card('b')]);
    await db.saveVerificationSummaries([
      _summary('v1', 'a', '2026-01-01T00:00:00.000Z'),
      _summary('v2', 'b', '2026-01-02T00:00:00.000Z'),
    ]);
    await db.saveVerificationDetail({'id': 'v1'});
    await db.removeCard('a');
    expect((await db.readVerificationSummaries()).map((v) => v['id']), ['v2']);
    expect(await db.readVerificationDetail('v1'), isNull);
  });

  test('verification summaries are newest first and filterable', () async {
    await db.saveVerificationSummaries([
      _summary('old', 'a', '2026-01-01T00:00:00.000Z'),
      _summary('new', 'a', '2026-02-01T00:00:00.000Z'),
      _summary('other', 'b', '2026-03-01T00:00:00.000Z'),
    ]);
    expect(
      (await db.readVerificationSummaries(cardId: 'a')).map((v) => v['id']),
      ['new', 'old'],
    );
    await db.saveVerificationSummaries([
      _summary('fresh', 'a', '2026-04-01T00:00:00.000Z'),
    ], replaceScopeCardId: 'a');
    expect(
      (await db.readVerificationSummaries(cardId: 'a')).map((v) => v['id']),
      ['fresh'],
    );
  });

  test('categories, merchants and clearAll', () async {
    await db.replaceCategories([
      {'id': 'c1'},
    ]);
    await db.replaceMerchants([
      {'id': 'm1'},
      {'id': 'm2'},
    ]);
    expect(await db.readCategories(), hasLength(1));
    expect(await db.readMerchants(), hasLength(2));
    await db.clearAll();
    expect(await db.readCategories(), isEmpty);
    expect(await db.readMerchants(), isEmpty);
  });

  test('upgrading from v1 drops stale verification payloads only', () async {
    // `raw` is the sqlite3 Database handed to drift's setup callback.
    void seedV1(dynamic raw) {
      if (raw.select('PRAGMA user_version').first.values.first != 0) return;
      raw.execute('''
        CREATE TABLE cached_cards (id TEXT NOT NULL PRIMARY KEY, position INTEGER NOT NULL, json TEXT NOT NULL);
        CREATE TABLE cached_verifications (id TEXT NOT NULL PRIMARY KEY, card_id TEXT NOT NULL, created_at INTEGER NOT NULL, json TEXT NOT NULL);
        CREATE TABLE cached_verification_details (id TEXT NOT NULL PRIMARY KEY, json TEXT NOT NULL);
        INSERT INTO cached_cards VALUES ('a', 0, '{"id":"a"}');
        INSERT INTO cached_verifications VALUES ('v1', 'a', 1767225600, '{"id":"v1"}');
        INSERT INTO cached_verification_details VALUES ('v1', '{"id":"v1"}');
        PRAGMA user_version = 1;
      ''');
    }

    final upgraded = AppDatabase(NativeDatabase.memory(setup: seedV1));
    addTearDown(upgraded.close);
    expect(await upgraded.readVerificationSummaries(), isEmpty);
    expect(await upgraded.readVerificationDetail('v1'), isNull);
    expect(await upgraded.readCards(), hasLength(1));
    expect(upgraded.schemaVersion, 2);
  });
}
