import 'package:dio/dio.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/cached.dart';
import '../domain/catalog_entities.dart';
import '../domain/catalog_repositories.dart';

abstract final class CatalogMapper {
  static Category category(Map<String, dynamic> j) => Category(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String?,
    merchantCount: (j['merchantCount'] as num?)?.toInt() ?? 0,
  );

  static Merchant merchant(Map<String, dynamic> j) => Merchant(
    id: j['id'] as String,
    name: j['name'] as String,
    categoryId: j['categoryId'] as String,
    keywords: [
      for (final k in (j['keywords'] as List<dynamic>? ?? const []))
        k as String,
    ],
  );
}

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  @override
  Future<Cached<List<Category>>> getCategories() =>
      networkFirst<List<JsonMap>, List<Category>>(
        fetch: () => guardApi(() async {
          final res = await _dio.get<List<dynamic>>('/categories');
          return res.data!.cast<JsonMap>();
        }),
        readCache: () async {
          final rows = await _db.readCategories();
          return rows.isEmpty ? null : rows;
        },
        writeCache: _db.replaceCategories,
        map: (raw) => raw.map(CatalogMapper.category).toList(),
      );

  @override
  Future<Category> createCategory({
    required String name,
    String? description,
  }) => guardApi(() async {
    final res = await _dio.post<JsonMap>(
      '/categories',
      data: {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return CatalogMapper.category(res.data!);
  });

  @override
  Future<void> updateCategory(String id, {String? name, String? description}) =>
      guardApi(() async {
        await _dio.patch<JsonMap>(
          '/categories/$id',
          data: {
            if (name != null) 'name': name.trim(),
            if (description != null)
              'description': description.trim().isEmpty
                  ? null
                  : description.trim(),
          },
        );
      });

  @override
  Future<void> deleteCategory(String id, {String? reassignTo}) =>
      guardApi(() async {
        await _dio.delete<void>(
          '/categories/$id',
          queryParameters: {'reassignTo': ?reassignTo},
        );
      });
}

class MerchantRepositoryImpl implements MerchantRepository {
  MerchantRepositoryImpl(this._dio, this._db);

  final Dio _dio;
  final AppDatabase _db;

  @override
  Future<Cached<List<Merchant>>> getMerchants() =>
      networkFirst<List<JsonMap>, List<Merchant>>(
        fetch: () => guardApi(() async {
          final res = await _dio.get<List<dynamic>>('/merchants');
          return res.data!.cast<JsonMap>();
        }),
        readCache: () async {
          final rows = await _db.readMerchants();
          return rows.isEmpty ? null : rows;
        },
        writeCache: _db.replaceMerchants,
        map: (raw) => raw.map(CatalogMapper.merchant).toList(),
      );

  @override
  Future<Merchant> createMerchant({
    required String name,
    required String categoryId,
    List<String> keywords = const [],
  }) => guardApi(() async {
    final res = await _dio.post<JsonMap>(
      '/merchants',
      data: {
        'name': name.trim(),
        'categoryId': categoryId,
        if (keywords.isNotEmpty) 'keywords': keywords,
      },
    );
    return CatalogMapper.merchant(res.data!);
  });

  @override
  Future<Merchant> updateMerchant(
    String id, {
    String? name,
    String? categoryId,
    List<String>? keywords,
  }) => guardApi(() async {
    final res = await _dio.patch<JsonMap>(
      '/merchants/$id',
      data: {
        'name': ?name?.trim(),
        'categoryId': ?categoryId,
        'keywords': ?keywords,
      },
    );
    return CatalogMapper.merchant(res.data!);
  });

  @override
  Future<void> deleteMerchant(String id) =>
      guardApi(() => _dio.delete<void>('/merchants/$id'));
}
