import 'package:get/get.dart';

import '../../../core/errors/error_messages.dart';
import '../../categories/presentation/catalog_controller.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

enum TransactionFilter { all, counted, uncounted }

/// Turns a raw statement descriptor into a friendlier merchant name/keyword
/// by dropping trailing branch numbers and `#` references.
String cleanDescriptor(String raw) {
  final tokens = raw.trim().split(RegExp(r'\s+'));
  while (tokens.length > 1 &&
      (tokens.last.startsWith('#') ||
          RegExp(r'^\d+$').hasMatch(tokens.last) ||
          tokens.last.toUpperCase() == 'SUC')) {
    tokens.removeLast();
  }
  return tokens.join(' ');
}

class ResultController extends GetxController {
  ResultController({
    required this._repository,
    required this._catalog,
    this.initial,
    this.verificationId,
  });

  final VerificationRepository _repository;
  final CatalogController _catalog;
  final Verification? initial;
  final String? verificationId;

  final verification = Rxn<Verification>();
  final loading = false.obs;
  final errorMessage = RxnString();
  final filter = TransactionFilter.all.obs;

  /// Transaction index -> category name assigned from this screen. The
  /// assignment affects future verifications, not this stored result.
  final assigned = <int, String>{}.obs;

  CatalogController get catalog => _catalog;

  @override
  void onInit() {
    super.onInit();
    verification.value = initial;
    if (initial == null && verificationId != null) load();
  }

  @override
  void onReady() {
    super.onReady();
    if (!_catalog.loaded.value) _catalog.load();
  }

  Future<void> load() async {
    loading.value = true;
    errorMessage.value = null;
    try {
      verification.value = (await _repository.detail(verificationId!)).data;
    } catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = false;
    }
  }

  void setFilter(TransactionFilter f) => filter.value = f;

  List<VerificationTransaction> get visibleTransactions {
    final all = verification.value?.transactions ?? const [];
    return switch (filter.value) {
      TransactionFilter.all => all,
      TransactionFilter.counted => all.where((t) => t.inCategory).toList(),
      TransactionFilter.uncounted => all.where((t) => !t.inCategory).toList(),
    };
  }

  /// Creates a merchant for an unmatched line so future statements match.
  /// Returns an error message or `null`.
  Future<String?> assignMerchant(
    VerificationTransaction tx, {
    required String name,
    required List<String> keywords,
    required String categoryId,
  }) async {
    final error = await _catalog.createMerchant(
      name: name,
      categoryId: categoryId,
      keywords: keywords,
    );
    if (error == null) {
      assigned[tx.index] = _catalog.categoryById(categoryId)?.name ?? '';
    }
    return error;
  }
}
