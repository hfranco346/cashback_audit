import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/categories/domain/catalog_entities.dart';
import 'package:cashback_audit/features/categories/domain/catalog_repositories.dart';

class FakeCategoryRepository implements CategoryRepository {
  FakeCategoryRepository(this.items);
  List<Category> items;
  AppException? deleteError;
  final deleted = <String>[];
  String? lastReassign;

  @override
  Future<Cached<List<Category>>> getCategories() async => Cached(items);

  @override
  Future<Category> createCategory({
    required String name,
    String? description,
  }) async {
    final c = Category(id: 'new-$name', name: name);
    items = [...items, c];
    return c;
  }

  @override
  Future<void> updateCategory(
    String id, {
    String? name,
    String? description,
  }) async {}

  @override
  Future<void> deleteCategory(String id, {String? reassignTo}) async {
    lastReassign = reassignTo;
    if (deleteError != null && reassignTo == null) throw deleteError!;
    deleted.add(id);
    items = items.where((c) => c.id != id).toList();
  }
}

class FakeMerchantRepository implements MerchantRepository {
  FakeMerchantRepository([List<Merchant>? items]) : items = items ?? [];
  List<Merchant> items;
  AppException? createError;
  final calls = <String>[];

  @override
  Future<Cached<List<Merchant>>> getMerchants() async => Cached(items);

  @override
  Future<Merchant> createMerchant({
    required String name,
    required String categoryId,
    List<String> keywords = const [],
  }) async {
    if (createError != null) throw createError!;
    calls.add('create:$name:$categoryId:${keywords.join('|')}');
    final m = Merchant(
      id: 'm-$name',
      name: name,
      categoryId: categoryId,
      keywords: keywords,
    );
    items = [...items, m];
    return m;
  }

  @override
  Future<Merchant> updateMerchant(
    String id, {
    String? name,
    String? categoryId,
    List<String>? keywords,
  }) async {
    calls.add('update:$id:${categoryId ?? '-'}');
    final old = items.firstWhere((m) => m.id == id);
    final m = Merchant(
      id: id,
      name: name ?? old.name,
      categoryId: categoryId ?? old.categoryId,
      keywords: keywords ?? old.keywords,
    );
    items = [for (final i in items) i.id == id ? m : i];
    return m;
  }

  @override
  Future<void> deleteMerchant(String id) async {
    calls.add('delete:$id');
    items = items.where((m) => m.id != id).toList();
  }
}
