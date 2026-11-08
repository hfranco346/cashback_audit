import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

typedef JsonMap = Map<String, dynamic>;

@DriftDatabase(
  tables: [
    CachedCards,
    CachedCategories,
    CachedMerchants,
    CachedVerifications,
    CachedVerificationDetails,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'cashback_audit'));

  /// Bump when the cached API payloads change shape. v2: two-step
  /// verifications (status, rates, loyalty, multi-currency lines).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Cached payloads are only a read model: drop the verification rows
      // written with the old contract and let the next fetch refill them.
      if (from < 2) {
        await delete(cachedVerifications).go();
        await delete(cachedVerificationDetails).go();
      }
    },
  );

  JsonMap _decode(String json) => jsonDecode(json) as JsonMap;

  // ---- cards ----
  Future<List<JsonMap>> readCards() async {
    final rows = await (select(
      cachedCards,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    return rows.map((r) => _decode(r.json)).toList();
  }

  Future<void> replaceCards(List<JsonMap> cards) => transaction(() async {
    await delete(cachedCards).go();
    await batch((b) {
      b.insertAll(cachedCards, [
        for (var i = 0; i < cards.length; i++)
          CachedCardsCompanion.insert(
            id: cards[i]['id'] as String,
            position: i,
            json: jsonEncode(cards[i]),
          ),
      ]);
    });
  });

  Future<void> upsertCard(JsonMap card) async {
    final existing = await (select(
      cachedCards,
    )..where((t) => t.id.equals(card['id'] as String))).getSingleOrNull();
    final position = existing?.position ?? await _nextPosition();
    await into(cachedCards).insertOnConflictUpdate(
      CachedCardsCompanion.insert(
        id: card['id'] as String,
        position: position,
        json: jsonEncode(card),
      ),
    );
  }

  Future<int> _nextPosition() async {
    final max = cachedCards.position.max();
    final row = await (selectOnly(cachedCards)..addColumns([max])).getSingle();
    return (row.read(max) ?? -1) + 1;
  }

  /// Removes a card and its cached verifications (the API cascades too).
  Future<void> removeCard(String id) => transaction(() async {
    await (delete(cachedCards)..where((t) => t.id.equals(id))).go();
    final ids = await (select(
      cachedVerifications,
    )..where((t) => t.cardId.equals(id))).map((r) => r.id).get();
    await (delete(cachedVerifications)..where((t) => t.cardId.equals(id))).go();
    await (delete(
      cachedVerificationDetails,
    )..where((t) => t.id.isIn(ids))).go();
  });

  // ---- categories ----
  Future<List<JsonMap>> readCategories() async {
    final rows = await (select(
      cachedCategories,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    return rows.map((r) => _decode(r.json)).toList();
  }

  Future<void> replaceCategories(List<JsonMap> items) => transaction(() async {
    await delete(cachedCategories).go();
    await batch((b) {
      b.insertAll(cachedCategories, [
        for (var i = 0; i < items.length; i++)
          CachedCategoriesCompanion.insert(
            id: items[i]['id'] as String,
            position: i,
            json: jsonEncode(items[i]),
          ),
      ]);
    });
  });

  // ---- merchants ----
  Future<List<JsonMap>> readMerchants() async {
    final rows = await (select(
      cachedMerchants,
    )..orderBy([(t) => OrderingTerm.asc(t.position)])).get();
    return rows.map((r) => _decode(r.json)).toList();
  }

  Future<void> replaceMerchants(List<JsonMap> items) => transaction(() async {
    await delete(cachedMerchants).go();
    await batch((b) {
      b.insertAll(cachedMerchants, [
        for (var i = 0; i < items.length; i++)
          CachedMerchantsCompanion.insert(
            id: items[i]['id'] as String,
            position: i,
            json: jsonEncode(items[i]),
          ),
      ]);
    });
  });

  // ---- verifications ----
  Future<List<JsonMap>> readVerificationSummaries({String? cardId}) async {
    final query = select(cachedVerifications)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (cardId != null) query.where((t) => t.cardId.equals(cardId));
    final rows = await query.get();
    return rows.map((r) => _decode(r.json)).toList();
  }

  /// Upserts summaries. When [replaceScopeCardId] is given (or [replaceAll]),
  /// summaries in that scope that are not in [items] are dropped first.
  Future<void> saveVerificationSummaries(
    List<JsonMap> items, {
    bool replaceAll = false,
    String? replaceScopeCardId,
  }) => transaction(() async {
    if (replaceAll) {
      await delete(cachedVerifications).go();
    } else if (replaceScopeCardId != null) {
      await (delete(
        cachedVerifications,
      )..where((t) => t.cardId.equals(replaceScopeCardId))).go();
    }
    await batch((b) {
      b.insertAllOnConflictUpdate(cachedVerifications, [
        for (final item in items)
          CachedVerificationsCompanion.insert(
            id: item['id'] as String,
            cardId: item['cardId'] as String,
            createdAt: DateTime.parse(item['createdAt'] as String),
            json: jsonEncode(item),
          ),
      ]);
    });
  });

  Future<JsonMap?> readVerificationDetail(String id) async {
    final row = await (select(
      cachedVerificationDetails,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _decode(row.json);
  }

  Future<void> saveVerificationDetail(JsonMap detail) =>
      into(cachedVerificationDetails).insertOnConflictUpdate(
        CachedVerificationDetailsCompanion.insert(
          id: detail['id'] as String,
          json: jsonEncode(detail),
        ),
      );

  Future<void> removeVerification(String id) => transaction(() async {
    await (delete(cachedVerifications)..where((t) => t.id.equals(id))).go();
    await (delete(
      cachedVerificationDetails,
    )..where((t) => t.id.equals(id))).go();
  });

  /// Wipes every cached row (used on logout).
  Future<void> clearAll() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}
