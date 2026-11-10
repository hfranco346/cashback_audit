import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../domain/catalog_entities.dart';
import '../domain/catalog_repositories.dart';

/// Outcome of trying to delete a category.
sealed class CategoryDeleteResult {
  const CategoryDeleteResult();
}

class CategoryDeleted extends CategoryDeleteResult {
  const CategoryDeleted();
}

/// The category still holds merchants and/or card rules (`CATEGORY_IN_USE`).
class CategoryInUse extends CategoryDeleteResult {
  const CategoryInUse({required this.merchants, required this.cardRules});
  final int merchants;
  final int cardRules;
}

class CategoryDeleteFailed extends CategoryDeleteResult {
  const CategoryDeleteFailed(this.message);
  final String message;
}

/// Categories ("rubros") and merchants, shared by the management screen, the
/// card rule editor and the "assign merchant" flow of the result screen.
class CatalogController extends GetxController {
  CatalogController({required this._categories, required this._merchants});

  final CategoryRepository _categories;
  final MerchantRepository _merchants;

  final categories = <Category>[].obs;
  final merchants = <Merchant>[].obs;
  final loading = false.obs;
  final loaded = false.obs;
  final offline = false.obs;
  final errorMessage = RxnString();

  @override
  void onReady() {
    super.onReady();
    load();
  }

  List<Merchant> merchantsOf(String categoryId) =>
      merchants.where((m) => m.categoryId == categoryId).toList();

  Category? categoryById(String? id) =>
      categories.firstWhereOrNull((c) => c.id == id);

  Future<void> load() async {
    loading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _categories.getCategories(),
        _merchants.getMerchants(),
      ]);
      final cats = results[0];
      final merch = results[1];
      categories.assignAll(cats.data as List<Category>);
      merchants.assignAll(merch.data as List<Merchant>);
      offline.value = cats.fromCache || merch.fromCache;
    } catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = false;
      loaded.value = true;
    }
  }

  /// Runs [action], then refreshes. Returns a message on failure.
  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (e) {
      return userMessageFor(e);
    }
    await load();
    return null;
  }

  Future<String?> createCategory(String name, String? description) => _mutate(
    () => _categories.createCategory(name: name, description: description),
  );

  /// Creates a category and returns it (for inline "create and select").
  /// Throws [AppException] on failure; the list is refreshed on success.
  Future<Category> createCategoryReturning(String name) async {
    final created = await _categories.createCategory(name: name);
    await load();
    return categoryById(created.id) ?? created;
  }

  Future<String?> updateCategory(
    String id, {
    required String name,
    String? description,
  }) => _mutate(
    () => _categories.updateCategory(
      id,
      name: name,
      description: description ?? '',
    ),
  );

  Future<CategoryDeleteResult> deleteCategory(
    String id, {
    String? reassignTo,
  }) async {
    try {
      await _categories.deleteCategory(id, reassignTo: reassignTo);
    } on AppException catch (e) {
      if (e.code == 'CATEGORY_IN_USE') {
        final d = e.details is Map ? e.details as Map : const {};
        return CategoryInUse(
          merchants: (d['merchants'] as num?)?.toInt() ?? 0,
          cardRules: (d['cardRules'] as num?)?.toInt() ?? 0,
        );
      }
      return CategoryDeleteFailed(userMessageFor(e));
    }
    await load();
    return const CategoryDeleted();
  }

  Future<String?> createMerchant({
    required String name,
    required String categoryId,
    List<String> keywords = const [],
  }) => _mutate(
    () => _merchants.createMerchant(
      name: name,
      categoryId: categoryId,
      keywords: keywords,
    ),
  );

  /// Edit and/or reassign a merchant.
  Future<String?> updateMerchant(
    String id, {
    String? name,
    String? categoryId,
    List<String>? keywords,
  }) => _mutate(
    () => _merchants.updateMerchant(
      id,
      name: name,
      categoryId: categoryId,
      keywords: keywords,
    ),
  );

  Future<String?> deleteMerchant(String id) =>
      _mutate(() => _merchants.deleteMerchant(id));
}

/// Splits a user-entered keyword string on commas/newlines.
List<String> parseKeywords(String raw) => raw
    .split(RegExp(r'[,\n]'))
    .map((k) => k.trim())
    .where((k) => k.isNotEmpty)
    .toList();
