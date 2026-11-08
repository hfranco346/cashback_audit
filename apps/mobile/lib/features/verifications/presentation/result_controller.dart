import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../categories/presentation/catalog_controller.dart';
import 'confirm_rates_controller.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

enum TransactionFilter { all, counted, uncounted, excluded }

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
    required this._navigator,
    this.initial,
    this.verificationId,
  });

  final VerificationRepository _repository;
  final CatalogController _catalog;
  final AppNavigator _navigator;
  final Verification? initial;
  final String? verificationId;

  final verification = Rxn<Verification>();
  final loading = false.obs;
  final errorMessage = RxnString();
  final filter = TransactionFilter.all.obs;

  /// A line was re-categorized but the free recalculation did not go through,
  /// so the displayed figures are the previous ones.
  final stale = false.obs;
  final recalculating = false.obs;

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
      TransactionFilter.uncounted => all.where((t) => t.outOfCategory).toList(),
      TransactionFilter.excluded => all.where((t) => t.isExcluded).toList(),
    };
  }

  /// Reopens the rate confirmation prefilled with the applied rates. The
  /// recalculation is free (no credit, no Claude call).
  Future<void> recalculateWithOtherRates() async {
    final v = verification.value;
    if (v == null) return;
    final result = await _navigator.pushForResult<Verification>(
      Routes.confirmRates,
      arguments: ConfirmRatesArgs.verification(v, returnToResult: true),
    );
    if (result != null) {
      verification.value = result;
      stale.value = false;
    }
  }

  /// Changes the category of one line (`null` clears it) and recalculates
  /// with the SAME applied rates. Returns a message to show, or `null`.
  Future<String?> correctCategory(
    VerificationTransaction tx,
    String? categoryId,
  ) async {
    final v = verification.value;
    if (v == null || recalculating.value) return null;
    if (categoryId == tx.categoryId) return null;
    recalculating.value = true;
    try {
      final patched = await _repository.correctTransaction(
        v.id,
        tx.index,
        categoryId,
      );
      verification.value = patched;
      return await _recalculateApplied(patched);
    } on AppException catch (e) {
      return userMessageFor(e);
    } finally {
      recalculating.value = false;
    }
  }

  /// Retries the free recalculation after a failed one.
  Future<String?> retryRecalculation() async {
    final v = verification.value;
    if (v == null || recalculating.value) return null;
    recalculating.value = true;
    try {
      return await _recalculateApplied(v);
    } finally {
      recalculating.value = false;
    }
  }

  Future<String?> _recalculateApplied(Verification v) async {
    final applied = v.appliedRates;
    if (applied == null) {
      // Verified before rates were confirmed: ask for them.
      stale.value = true;
      await recalculateWithOtherRates();
      return null;
    }
    try {
      verification.value = await _repository.confirm(
        v.id,
        ConfirmRequest.fromApplied(applied),
      );
      stale.value = false;
      return S.categoryChanged;
    } on AppException catch (e) {
      stale.value = true;
      if (e.code == 'RATES_REQUIRED') {
        // The new category needs its own rate: let the user set it.
        await recalculateWithOtherRates();
        return S.recalcNeedsRate;
      }
      return S.recalcFailedAfterChange;
    }
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
