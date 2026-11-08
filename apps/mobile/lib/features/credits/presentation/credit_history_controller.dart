import 'package:get/get.dart';

import '../../../core/errors/error_messages.dart';
import '../domain/credit_entities.dart';
import '../domain/credits_repository.dart';

/// Paginated credit ledger.
class CreditHistoryController extends GetxController {
  CreditHistoryController({required this._repository, this.pageSize = 20});

  final CreditsRepository _repository;
  final int pageSize;

  final items = <CreditHistoryEntry>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final hasMore = false.obs;
  final errorMessage = RxnString();
  int _page = 1;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    errorMessage.value = null;
    _page = 1;
    try {
      final r = await _repository.history(pageSize: pageSize);
      items.assignAll(r.items);
      hasMore.value = r.hasMore;
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
      final r = await _repository.history(page: _page + 1, pageSize: pageSize);
      _page += 1;
      items.addAll(r.items);
      hasMore.value = r.hasMore;
    } catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      loadingMore.value = false;
    }
  }
}
