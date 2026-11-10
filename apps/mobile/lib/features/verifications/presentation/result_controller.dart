import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../../categories/presentation/catalog_controller.dart';
import 'attention_controller.dart';
import 'confirm_rates_controller.dart';
import 'delete_verification.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

enum TransactionFilter { all, counted, uncounted, excluded }

/// Title-cases an all-caps descriptor for display ("COMIDAS ESPECIALES
/// EBERSO" -> "Comidas Especiales Eberso"); mixed-case text is kept.
String displayMerchantName(String raw) {
  final clean = cleanDescriptor(raw);
  if (clean != clean.toUpperCase()) return clean;
  return clean
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Message shown under the result tabs after an action.
class ResultNotice {
  const ResultNotice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

enum ResultTab { summary, categories, movements }

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
    this.cards,
    this.attention,
    this.credits,
  });

  final VerificationRepository _repository;
  final CatalogController _catalog;
  final AppNavigator _navigator;
  final Verification? initial;
  final String? verificationId;
  final CardsController? cards;
  final AttentionController? attention;
  final CreditsController? credits;

  final verification = Rxn<Verification>();
  final loading = false.obs;
  final errorMessage = RxnString();
  final filter = TransactionFilter.all.obs;

  /// A line was re-categorized but the free recalculation did not go through,
  /// so the displayed figures are the previous ones.
  final stale = false.obs;
  final recalculating = false.obs;

  final tab = ResultTab.summary.obs;

  /// Outcome of the last action (category change, recalculation).
  final notice = Rxn<ResultNotice>();
  bool _seenMarked = false;

  CatalogController get catalog => _catalog;

  @override
  void onInit() {
    super.onInit();
    verification.value = initial;
    if (initial == null && verificationId != null) {
      load();
    } else {
      _markSeen();
    }
  }

  /// A finished result that was opened is "seen": it leaves Home's pending
  /// list. Failures are ignored (the next refresh brings it back).
  void _markSeen() {
    final v = verification.value;
    if (_seenMarked || v == null || !v.isCompleted) return;
    _seenMarked = true;
    final done = attention?.markSeen(v.id) ?? _repository.markSeen(v.id);
    done.catchError((Object _) {});
  }

  /// `BAC Cash •••• 4821`, falling back to the bank name from the statement.
  String get cardLabel {
    final v = verification.value;
    final card = v == null ? null : cards?.byId(v.cardId);
    if (card != null) return '${card.alias} •••• ${card.last4}';
    final last4 = v?.statement.cardLast4;
    final bank = v?.statement.bank;
    return [?bank, if (last4 != null) '•••• $last4'].join(' ');
  }

  void setTab(ResultTab t) => tab.value = t;

  /// The confirmation must say the check used is not returned.
  bool get deleteLosesCreditNote =>
      deleteLosesCredit(credits: credits, status: verification.value?.status);

  final deleting = false.obs;

  /// Deletes this verification (already confirmed by the user). On success it
  /// goes back to where the user came from with a snackbar; the lists refresh
  /// through the repository's change events. Returns the error message, or
  /// `null` when it worked.
  Future<String?> deleteVerification() async {
    final id = verification.value?.id ?? verificationId;
    if (id == null || deleting.value) return null;
    deleting.value = true;
    try {
      final error = await deleteVerificationById(_repository, id);
      if (error != null) return error;
      attention?.reload();
      _navigator.pop();
      _navigator.showNotice(S.current.deleteVerificationDone, '');
      return null;
    } finally {
      deleting.value = false;
    }
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
      _markSeen();
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

  /// Opens the claim-to-the-bank email for an underpaid result.
  void openClaim() {
    final v = verification.value;
    if (v == null || v.verdict != Verdict.underpaid) return;
    _navigator.push(Routes.claim, arguments: v);
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
  /// with the SAME applied rates. With [remember] the merchant is also
  /// created or updated so future verifications match it. Returns the
  /// message to show, or `null` when nothing changed.
  Future<ResultNotice?> changeCategory(
    VerificationTransaction tx,
    String? categoryId, {
    bool remember = false,
  }) async {
    final v = verification.value;
    if (v == null || recalculating.value) return null;
    if (categoryId == tx.categoryId && !remember) return null;
    recalculating.value = true;
    notice.value = null;
    try {
      if (categoryId != tx.categoryId) {
        final patched = await _repository.correctTransaction(
          v.id,
          tx.index,
          categoryId,
        );
        verification.value = patched;
      }
      final rememberError = remember && categoryId != null
          ? await _rememberMerchant(tx, categoryId)
          : null;
      final problem = await _recalculateApplied(verification.value!);
      final result =
          problem ??
          (rememberError != null
              ? ResultNotice(
                  S.current.rememberFailed(rememberError),
                  isError: true,
                )
              : ResultNotice(
                  remember && categoryId != null
                      ? S.current.categoryChangedRemembered
                      : S.current.categoryChanged,
                ));
      notice.value = result;
      return result;
    } on AppException catch (e) {
      final result = ResultNotice(userMessageFor(e), isError: true);
      notice.value = result;
      return result;
    } finally {
      recalculating.value = false;
    }
  }

  /// Creates the merchant for an unmatched line or moves the one it already
  /// matched (or shares its name) to [categoryId], adding the statement
  /// keyword so the next statements match it. Returns an error or `null`.
  Future<String?> _rememberMerchant(
    VerificationTransaction tx,
    String categoryId,
  ) async {
    final keyword = cleanDescriptor(tx.merchant);
    if (!_catalog.loaded.value) await _catalog.load();
    final name = tx.matchedMerchantName ?? displayMerchantName(tx.merchant);
    final byId = _catalog.merchants.firstWhereOrNull(
      (m) => m.id == tx.matchedMerchantId,
    );
    if (byId == null && tx.matchedMerchantId != null) {
      // Matched a merchant the catalog no longer lists: just move it.
      return _catalog.updateMerchant(
        tx.matchedMerchantId!,
        categoryId: categoryId,
      );
    }
    final existing =
        byId ??
        _catalog.merchants.firstWhereOrNull(
          (m) => m.name.toLowerCase() == name.toLowerCase(),
        );
    if (existing == null) {
      return _catalog.createMerchant(
        name: name,
        categoryId: categoryId,
        keywords: [keyword],
      );
    }
    final hasKeyword = existing.keywords.any(
      (k) => k.toLowerCase() == keyword.toLowerCase(),
    );
    return _catalog.updateMerchant(
      existing.id,
      categoryId: categoryId,
      keywords: hasKeyword ? null : [...existing.keywords, keyword],
    );
  }

  /// Retries the free recalculation after a failed one.
  Future<ResultNotice?> retryRecalculation() async {
    final v = verification.value;
    if (v == null || recalculating.value) return null;
    recalculating.value = true;
    try {
      final result =
          await _recalculateApplied(v) ??
          ResultNotice(S.current.categoryChanged);
      notice.value = result;
      return result;
    } finally {
      recalculating.value = false;
    }
  }

  /// Recalculates with the applied rates. `null` means it worked; otherwise
  /// the notice explains what is pending.
  Future<ResultNotice?> _recalculateApplied(Verification v) async {
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
      return null;
    } on AppException catch (e) {
      stale.value = true;
      if (e.code == 'RATES_REQUIRED') {
        // The new category needs its own rate: let the user set it.
        await recalculateWithOtherRates();
        return ResultNotice(S.current.recalcNeedsRate);
      }
      return ResultNotice(S.current.recalcFailedAfterChange, isError: true);
    }
  }
}
