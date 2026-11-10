import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_events.dart';
import '../domain/verification_repository.dart';
import 'auto_refresh.dart';
import 'verification_navigation.dart';

class HistoryController extends GetxController {
  HistoryController({
    required this._repository,
    required this._navigator,
    this.initialCardId,
    this.pageSize = 20,
    this.events,
    this.shell,
    this.isRouteOnTop,
    this.pollInterval = const Duration(seconds: 5),
  });

  final VerificationRepository _repository;
  final AppNavigator _navigator;
  final String? initialCardId;
  final int pageSize;

  /// Wiring of the automatic refresh (all optional so the controller stays
  /// usable on its own): change events, the shell's selected tab (History is
  /// tab 1), whether the route is on top, and the poll period.
  final VerificationEvents? events;
  final RxInt? shell;
  final bool Function()? isRouteOnTop;
  final Duration pollInterval;

  late final AutoRefresh _auto = AutoRefresh(
    refresh: refreshSilently,
    hasPending: () => items.any((e) => e.isProcessing),
    events: events,
    tab: shell,
    tabIndex: 1,
    isRouteOnTop: isRouteOnTop,
    interval: pollInterval,
  );

  final cardFilter = RxnString();
  final items = <VerificationSummary>[].obs;
  final loading = false.obs;
  final loadingMore = false.obs;
  final offline = false.obs;

  /// When the cached history shown offline was saved, if known.
  final cachedAt = Rxn<DateTime>();
  final hasMore = false.obs;
  final errorMessage = RxnString();
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    cardFilter.value = initialCardId;
    _auto.start();
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
      cachedAt.value = r.cachedAt;
    } catch (e) {
      items.clear();
      hasMore.value = false;
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = false;
      _auto.sync();
    }
  }

  /// Silent reload of the first page (no spinner, errors ignored): what the
  /// poll, the app resume and the change events run. Pages already loaded
  /// with "load more" stay; their rows are updated in place.
  Future<void> refreshSilently() async {
    if (loading.value) return;
    final r = await _repository.history(
      cardId: cardFilter.value,
      pageSize: pageSize,
    );
    final fresh = r.data.items;
    if (_page == 1) {
      items.assignAll(fresh);
      hasMore.value = r.data.hasMore;
    } else {
      final byId = {for (final f in fresh) f.id: f};
      final known = {for (final i in items) i.id};
      items.assignAll([
        for (final f in fresh)
          if (!known.contains(f.id)) f,
        for (final i in items) byId[i.id] ?? i,
      ]);
    }
    offline.value = r.fromCache;
    cachedAt.value = r.cachedAt;
    errorMessage.value = null;
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

  /// Opens the result (or the rate confirmation when still pending); the
  /// detail is fetched (or served from cache).
  void open(VerificationSummary summary) =>
      openVerificationSummary(_navigator, summary);

  @override
  void onClose() {
    _auto.dispose();
    super.onClose();
  }

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
