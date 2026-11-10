import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../auth/domain/auth_entities.dart';
import '../../cards/domain/card_entities.dart';
import '../../cards/domain/card_validator.dart';
import '../../verifications/domain/pdf_picker.dart';
import '../../verifications/domain/verification_entities.dart';
import '../../verifications/domain/verification_repository.dart';
import '../../verifications/presentation/confirm_rates_controller.dart';
import '../../verifications/presentation/verification_poller.dart';
import '../data/onboarding_sync.dart';
import '../domain/onboarding_draft.dart';
import '../domain/onboarding_repository.dart';

/// Banks offered first; `tested` ones have been checked end to end.
const onboardingBanks = <({String name, bool tested})>[
  (name: 'BAC Credomatic', tested: true),
  (name: 'Banco Ficohsa', tested: true),
  (name: 'Banco Atlántida', tested: false),
  (name: 'Banpaís', tested: false),
];

/// Currencies offered as chips (plus "detect it for me").
const onboardingCurrencies = ['HNL', 'USD', 'MXN'];

enum FirstPdfPhase { pick, uploading, processing, failed }

/// Guided setup: every step saves real data (bank → card → categories → sign
/// in → first PDF with the free check → first verdict). Data captured before
/// sign-in stays on the device ([OnboardingDraftRepository]) and is pushed to
/// the backend right after sign-in ([OnboardingSync]).
class OnboardingController extends GetxController {
  OnboardingController({
    required this._drafts,
    required this._onboarding,
    required this._navigator,
    required this._sync,
    required this._verifications,
    required this._picker,
    required this.isSignedIn,
    this.userName,
    this.onDataChanged,
    this.hasFreeCheck,
    VerificationPoller? poller,
  }) : _poller = poller ?? VerificationPoller(repository: _verifications);

  static const maxBytes = 10 * 1024 * 1024;

  final OnboardingDraftRepository _drafts;
  final OnboardingRepository _onboarding;
  final AppNavigator _navigator;
  final OnboardingSync _sync;
  final VerificationRepository _verifications;
  final PdfPicker _picker;
  final VerificationPoller _poller;

  /// Whether a session exists already (guided setup reopened from Home).
  final bool Function() isSignedIn;
  final String? Function()? userName;

  /// Called after the card/categories reached the backend, so shared stores
  /// (cards, catalog, credits) reload.
  final Future<void> Function()? onDataChanged;

  /// `false` when the account is known to have no credit left.
  final bool Function()? hasFreeCheck;

  final step = OnboardingStep.demo.obs;
  final draft = const OnboardingDraft().obs;
  final bankQuery = ''.obs;
  final syncing = false.obs;
  final syncError = RxnString();

  final pdfPhase = FirstPdfPhase.pick.obs;
  final file = Rxn<PickedPdf>();
  final pdfError = RxnString();
  final verification = Rxn<Verification>();
  final failure = Rxn<FailureCode>();

  bool _loaded = false;

  String get cardName =>
      draft.value.alias.trim().isEmpty ? draft.value.bank : draft.value.alias;

  /// 1-based number for "Step N of 5"; 0 when the header is hidden.
  int get stepNumber => switch (step.value) {
    OnboardingStep.bank => 1,
    OnboardingStep.card => 2,
    OnboardingStep.categories => 3,
    OnboardingStep.account => 4,
    OnboardingStep.pdf => 5,
    _ => 0,
  };

  @override
  void onReady() {
    super.onReady();
    load();
  }

  /// Restores the saved draft (and where the user was).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final saved = await _drafts.read();
    final signedIn = isSignedIn();
    if (saved != null) draft.value = saved;
    if (signedIn && (saved == null || saved.step == OnboardingStep.demo)) {
      // Reopened from Home: no demo, straight to the bank.
      await _go(OnboardingStep.bank);
      return;
    }
    if (saved == null) return;
    var target = saved.step;
    if (target == OnboardingStep.verdict) target = OnboardingStep.pdf;
    if (target.index >= OnboardingStep.account.index) {
      if (signedIn) {
        step.value = OnboardingStep.account;
        await _syncAndContinue();
        return;
      }
      target = OnboardingStep.account;
    }
    step.value = target;
  }

  Future<void> _go(OnboardingStep next) async {
    step.value = next;
    draft.value = draft.value.copyWith(step: next);
    try {
      await _drafts.save(draft.value);
    } on Object {
      // The draft is a convenience: never block the flow on storage.
    }
  }

  // ---- navigation ----

  Future<void> start() => _go(OnboardingStep.bank);

  Future<void> back() async {
    switch (step.value) {
      case OnboardingStep.bank:
        if (isSignedIn()) return _exit();
        await _go(OnboardingStep.demo);
      case OnboardingStep.card:
        await _go(OnboardingStep.bank);
      case OnboardingStep.categories:
        await _go(OnboardingStep.card);
      case OnboardingStep.account:
        await _go(OnboardingStep.categories);
      case OnboardingStep.pdf:
      case OnboardingStep.verdict:
        await leaveToHome();
      case OnboardingStep.demo:
        break;
    }
  }

  Future<void> next() async {
    if (!canContinue) return;
    switch (step.value) {
      case OnboardingStep.bank:
        return _go(OnboardingStep.card);
      case OnboardingStep.card:
        return _go(OnboardingStep.categories);
      case OnboardingStep.categories:
        if (isSignedIn()) {
          await _go(OnboardingStep.account);
          return _syncAndContinue();
        }
        return _go(OnboardingStep.account);
      default:
        return;
    }
  }

  /// Skip the guided setup: nothing is saved and the draft is dropped.
  Future<void> skipSetup() async {
    await _onboarding.markOnboardingSeen();
    await _drafts.clear();
    _navigator.offAll(isSignedIn() ? Routes.home : Routes.login);
  }

  /// "I already have an account".
  Future<void> haveAccount() async {
    await _onboarding.markOnboardingSeen();
    _navigator.offAll(Routes.login);
  }

  Future<void> _exit() async {
    _navigator.offAll(Routes.home);
  }

  // ---- bank ----

  void selectBank(String name) =>
      draft.value = draft.value.copyWith(bank: name);

  void setBankOther(String name) =>
      draft.value = draft.value.copyWith(bank: name.trim());

  // ---- card ----

  void setAlias(String v) => draft.value = draft.value.copyWith(alias: v);
  void setLast4(String v) => draft.value = draft.value.copyWith(last4: v);
  void setUnit(RewardUnit u) =>
      draft.value = draft.value.copyWith(rewardUnit: u);
  void setCurrency(String? code) =>
      draft.value = draft.value.copyWith(currency: () => code);

  // ---- categories ----

  bool isSelected(String name) => draft.value.categories.any(
    (c) => c.name.toLowerCase() == name.toLowerCase(),
  );

  /// Common rate the design prefills for the first categories.
  static const seedRate = '7';

  /// Offers the common categories once (selected at [seedRate]%), as the
  /// design does. Never overrides what the user already ticked or cleared.
  void seedCategories(List<String> names) {
    final d = draft.value;
    if (d.categoriesSeeded) return;
    draft.value = d.copyWith(
      categoriesSeeded: true,
      categories: d.categories.isNotEmpty
          ? null
          : [for (final n in names) DraftCategory(name: n, rate: seedRate)],
    );
  }

  void toggleCategory(String name) {
    final list = [...draft.value.categories];
    final i = list.indexWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (i >= 0) {
      list.removeAt(i);
    } else {
      list.add(DraftCategory(name: name));
    }
    draft.value = draft.value.copyWith(
      categories: list,
      categoriesSeeded: true,
    );
  }

  void setCategoryRate(String name, String rate) {
    draft.value = draft.value.copyWith(
      categories: [
        for (final c in draft.value.categories)
          c.name == name ? c.withRate(rate) : c,
      ],
    );
  }

  void setBaseRate(String v) => draft.value = draft.value.copyWith(baseRate: v);

  // ---- validation ----

  bool get canContinue {
    final d = draft.value;
    return switch (step.value) {
      OnboardingStep.bank => d.bank.trim().isNotEmpty,
      OnboardingStep.card => CardValidator.last4(d.last4) == null,
      OnboardingStep.categories =>
        CardValidator.percent(d.baseRate) == null &&
            d.categories.every(
              (c) =>
                  c.rate.trim().isEmpty ||
                  CardValidator.percent(c.rate) == null,
            ),
      _ => true,
    };
  }

  // ---- account → sync ----

  /// Hooked to the login controller: the user just signed in.
  Future<void> afterSignIn(AppUser user) async {
    await _onboarding.markOnboardingSeen();
    await _syncAndContinue();
  }

  Future<void> retrySync() => _syncAndContinue();

  Future<void> _syncAndContinue() async {
    if (syncing.value) return;
    syncing.value = true;
    syncError.value = null;
    try {
      draft.value = await _sync.sync(draft.value);
      await onDataChanged?.call();
      await _onboarding.markOnboardingSeen();
      if (hasFreeCheck != null && !hasFreeCheck!()) {
        await _finishWithoutCheck();
      } else {
        await _go(OnboardingStep.pdf);
      }
    } catch (e) {
      syncError.value = userMessageFor(e);
    } finally {
      syncing.value = false;
    }
  }

  Future<void> _finishWithoutCheck() async {
    await _drafts.clear();
    _navigator.offAll(Routes.home);
  }

  // ---- first PDF ----

  Future<void> pickPdf() async {
    final picked = await _picker.pick();
    if (picked == null) return;
    pdfError.value = null;
    if (!picked.name.toLowerCase().endsWith('.pdf') ||
        picked.sizeBytes > maxBytes) {
      pdfError.value = picked.sizeBytes > maxBytes ? 'size' : 'type';
      return;
    }
    file.value = picked;
  }

  bool get canAnalyze =>
      file.value != null &&
      draft.value.cardId != null &&
      pdfPhase.value == FirstPdfPhase.pick;

  Future<void> startAnalysis() async {
    if (!canAnalyze) return;
    pdfError.value = null;
    pdfPhase.value = FirstPdfPhase.uploading;
    try {
      final v = await _verifications.upload(
        cardId: draft.value.cardId!,
        filePath: file.value!.path,
      );
      verification.value = v;
      pdfPhase.value = FirstPdfPhase.processing;
      _handleVerification(v);
      if (v.isProcessing) _watch(v.id);
    } on AppException catch (e) {
      pdfPhase.value = FirstPdfPhase.pick;
      if (e.isNoCredits) {
        await _finishWithoutCheck();
        return;
      }
      pdfError.value = userMessageFor(e);
    }
  }

  void _watch(String id) {
    _poller.start(
      id,
      onUpdate: _handleVerification,
      onError: (e, {required fatal}) {
        if (fatal) pdfError.value = userMessageFor(e);
      },
    );
  }

  void _handleVerification(Verification v) {
    verification.value = v;
    if (v.isAwaitingRates) {
      _poller.stop();
      _confirmRates(v);
    } else if (v.isFailed) {
      _poller.stop();
      failure.value = v.failureCode;
      pdfPhase.value = FirstPdfPhase.failed;
    }
  }

  /// The percentages are always confirmed by the user, even in the setup.
  Future<void> _confirmRates(Verification v) async {
    final confirmed = await _navigator.pushForResult<Verification>(
      Routes.confirmRates,
      arguments: ConfirmRatesArgs.verification(v, returnToResult: true),
    );
    if (confirmed != null) {
      verification.value = confirmed;
      await _onboarding.markOnboardingSeen();
      await _drafts.clear();
      await _drafts.setJustOnboarded(true);
      step.value = OnboardingStep.verdict;
    } else {
      // Left the confirmation: it stays pending and Home shows it.
      await leaveToHome();
    }
  }

  /// A failed read refunds the credit: pick another file.
  void retryPdf() {
    file.value = null;
    failure.value = null;
    verification.value = null;
    pdfPhase.value = FirstPdfPhase.pick;
  }

  /// "Go to my home": a running analysis continues in the backend.
  Future<void> leaveToHome() async {
    _poller.stop();
    await _onboarding.markOnboardingSeen();
    if (step.value != OnboardingStep.verdict) await _drafts.clear();
    _navigator.offAll(Routes.home);
  }

  void openDetail() {
    final v = verification.value;
    if (v == null) return;
    _navigator.offAll(Routes.home);
    _navigator.push(Routes.result, arguments: v);
  }

  @override
  void onClose() {
    _poller.stop();
    super.onClose();
  }
}
