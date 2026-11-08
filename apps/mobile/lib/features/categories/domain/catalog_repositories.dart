import '../../../core/utils/cached.dart';
import 'catalog_entities.dart';

abstract class CategoryRepository {
  Future<Cached<List<Category>>> getCategories();
  Future<Category> createCategory({required String name, String? description});
  Future<void> updateCategory(String id, {String? name, String? description});

  /// Throws `CATEGORY_IN_USE` (409) when it still has merchants or card rules
  /// unless [reassignTo] is given.
  Future<void> deleteCategory(String id, {String? reassignTo});
}

abstract class MerchantRepository {
  Future<Cached<List<Merchant>>> getMerchants();
  Future<Merchant> createMerchant({
    required String name,
    required String categoryId,
    List<String> keywords = const [],
  });

  /// Only non-null arguments are sent. `keywords` replaces the whole list.
  Future<Merchant> updateMerchant(
    String id, {
    String? name,
    String? categoryId,
    List<String>? keywords,
  });
  Future<void> deleteMerchant(String id);
}
