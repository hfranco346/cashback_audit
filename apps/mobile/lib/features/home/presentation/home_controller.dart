import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../cards/domain/card_entities.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../categories/presentation/catalog_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../../onboarding/data/onboarding_sync.dart';
import '../../onboarding/domain/onboarding_draft.dart';
import '../../verifications/domain/verification_repository.dart';
import '../../verifications/presentation/attention_controller.dart';
import '../../verifications/presentation/history_controller.dart';

/// Which of the three designed Home states applies.
enum HomeLayout {
  /// Cards still loading for the first time.
  loading,

  /// Skipped the setup: no cards yet.
  empty,

  /// Just finished the guided setup: exactly what was registered.
  fresh,

  /// Regular use.
  full,
}

/// Start-up work of the signed-in area and the data Home shows. Pending
/// verifications (`attention`) refresh on load and whenever the app resumes.
class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController({
    required this._attention,
    required this._cards,
    required this._catalog,
    required this._latest,
    required this._credits,
    required this._drafts,
    required this._verifications,
    required this._sync,
    required this.startup,
    this.isSignedIn,
  });

  final AttentionController _attention;
  final CardsController _cards;
  final CatalogController _catalog;
  final LatestVerificationsController _latest;
  final CreditsController _credits;
  final OnboardingDraftRepository _drafts;
  final VerificationRepository _verifications;
  final OnboardingSync _sync;

  /// Restores the user and refreshes subscription status (wired by the
  /// binding, so this controller stays testable).
  final Future<void> Function() startup;
  final bool Function()? isSignedIn;

  /// The guided setup just ended: Home mirrors what was registered.
  final fresh = false.obs;

  /// Purchases without category in the first verification (fresh state).
  final uncategorized = 0.obs;

  AttentionController get attention => _attention;
  CardsController get cards => _cards;
  CatalogController get catalog => _catalog;
  LatestVerificationsController get latest => _latest;
  CreditsController get credits => _credits;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    _begin();
  }

  Future<void> _begin() async {
    await startup();
    _attention.reload();
    await _syncPendingDraft();
    await _loadFresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attention.reload();
      _latest.load();
      _credits.fetch();
    }
  }

  /// The user signed in during the setup but the app closed before the
  /// draft reached the backend: finish it quietly.
  Future<void> _syncPendingDraft() async {
    try {
      if (isSignedIn != null && !isSignedIn!()) return;
      final draft = await _drafts.read();
      if (draft == null ||
          draft.isSynced ||
          draft.step.index < OnboardingStep.account.index) {
        return;
      }
      await _sync.sync(draft);
      await _cards.load();
      await _catalog.load();
    } catch (_) {
      // Stays on the device; the next Home load tries again.
    }
  }

  Future<void> _loadFresh() async {
    try {
      fresh.value = await _drafts.isJustOnboarded();
      if (!fresh.value) return;
      await _latest.load();
      final first = _latest.items.firstOrNull;
      if (first != null && first.isCompleted) {
        final detail = await _verifications.detail(first.id);
        uncategorized.value = detail.data.uncountedTransactions;
      }
    } catch (_) {
      // The notice is optional.
    }
  }

  /// Leaves the "just onboarded" view (the user moved on).
  Future<void> dismissFresh() async {
    if (!fresh.value) return;
    fresh.value = false;
    try {
      await _drafts.setJustOnboarded(false);
    } catch (_) {}
  }

  HomeLayout get layout {
    final list = _cards.cards;
    if (!_cards.loaded.value && list.isEmpty) return HomeLayout.loading;
    if (list.isEmpty) return HomeLayout.empty;
    if (fresh.value && list.length == 1 && _latest.items.length <= 1) {
      return HomeLayout.fresh;
    }
    return HomeLayout.full;
  }

  Future<void> refreshAll() async {
    await Future.wait([
      _cards.load(),
      _latest.load(),
      _credits.fetch(),
      _attention.reload(),
      _catalog.load(),
    ]);
  }

  String cardLabel(String id) {
    final c = _cards.byId(id);
    return c == null ? '—' : '${c.alias} · ${c.last4}';
  }

  String categoryName(String id) => _catalog.categoryById(id)?.name ?? '';

  Future<String?> deleteCard(CreditCard card) => _cards.delete(card);

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
