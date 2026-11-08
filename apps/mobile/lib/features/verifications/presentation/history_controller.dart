import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

class HistoryController extends GetxController {
  HistoryController({
    required this._repository,
    required this._navigator,
    this.initialCardId,
    this.pageSize = 20,
  });

  final VerificationRepository _repository;
  final AppNavigator _navigator;
  final String? initialCardId;
  final int pageSize;

  final cardFilter = RxnString();
  final items = <VerificationSummary>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final offline = false.obs;
  final hasMore = false.obs;
  final errorMessage = RxnString();
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    cardFilter.value = initialCardId;
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> setCard(String? id) {
    cardFilter.value = id;
    return load();
  }

  Future<void> load() async {
    loading.value = true;
    errorMessage.value = null;
    _page = 1;
    try {
      final r = await _repository.history(
        cardId: cardFilter.value,
        pageSize: pageSize,
      );
      items.assignAll(r.data.items);
      hasMore.value = r.data.hasMore;
      offline.value = r.fromCache;
    } catch (e) {
      items.clear();
      hasMore.value = false;
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingMore.value || !hasMore.value) return;
    loadingMore.value = true;
    try {
      final r = await _repository.history(
        cardId: cardFilter.value,
        page: _page + 1,
        pageSize: pageSize,
      );
      _page += 1;
      items.addAll(r.data.items);
      hasMore.value = r.data.hasMore;
    } catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      loadingMore.value = false;
    }
  }

  /// Opens the full result; the detail is fetched (or served from cache).
  void open(VerificationSummary summary) =>
      _navigator.push(Routes.result, arguments: summary.id);

  Future<String?> delete(VerificationSummary summary) async {
    try {
      await _repository.delete(summary.id);
      items.removeWhere((i) => i.id == summary.id);
      return null;
    } on AppException catch (e) {
      return userMessageFor(e);
    }
  }
}

/// The few latest verifications shown on the home screen.
class LatestVerificationsController extends GetxController {
  LatestVerificationsController(this._repository);

  final VerificationRepository _repository;
  final items = <VerificationSummary>[].obs;
  final loading = false.obs;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final r = await _repository.history(pageSize: 3);
      items.assignAll(r.data.items);
    } catch (_) {
      // The home screen stays usable without this section.
    } finally {
      loading.value = false;
    }
  }
}
