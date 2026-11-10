import 'package:dio/dio.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/cached.dart';
import '../domain/card_entities.dart';
import '../domain/card_repository.dart';
import 'card_mapper.dart';

class CardRepositoryImpl implements CardRepository, ClaimEmailRepository {
  CardRepositoryImpl(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  @override
  Future<Cached<List<CreditCard>>> getCards() =>
      networkFirst<List<JsonMap>, List<CreditCard>>(
        fetch: () => guardApi(() async {
          final res = await _dio.get<List<dynamic>>('/cards');
          return res.data!.cast<JsonMap>();
        }),
        readCache: () async {
          final rows = await _db.readCards();
          return rows.isEmpty ? null : rows;
        },
        writeCache: _db.replaceCards,
        map: (raw) => raw.map(CardMapper.fromJson).toList(),
      );

  @override
  Future<CreditCard> createCard(CardDraft draft) => guardApi(() async {
    final res = await _dio.post<JsonMap>(
      '/cards',
      data: CardMapper.toRequest(draft, forUpdate: false),
    );
    await _db.upsertCard(res.data!);
    return CardMapper.fromJson(res.data!);
  });

  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      guardApi(() async {
        final res = await _dio.patch<JsonMap>(
          '/cards/$id',
          data: CardMapper.toRequest(draft, forUpdate: true),
        );
        await _db.upsertCard(res.data!);
        return CardMapper.fromJson(res.data!);
      });

  @override
  Future<CreditCard> setClaimEmail(String id, String? email) =>
      guardApi(() async {
        final res = await _dio.patch<JsonMap>(
          '/cards/$id',
          data: {'claimEmail': email},
        );
        await _db.upsertCard(res.data!);
        return CardMapper.fromJson(res.data!);
      });

  @override
  Future<void> deleteCard(String id) => guardApi(() async {
    await _dio.delete<void>('/cards/$id');
    await _db.removeCard(id);
  });
}
