import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../cards/domain/card_entities.dart';
import '../../cards/domain/card_validator.dart';
import '../../cards/presentation/cards_controller.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';

/// Where the confirmation screen gets its verification from and where it
/// goes afterwards.
class ConfirmRatesArgs {
  /// Fresh step-1 result (upload) or a completed one being recalculated.
  const ConfirmRatesArgs.verification(
    Verification this.verification, {
    this.returnToResult = false,
  }) : verificationId = null;

  /// Resume from history: the detail is fetched.
  const ConfirmRatesArgs.byId(String this.verificationId)
    : verification = null,
      returnToResult = false;

  final Verification? verification;
  final String? verificationId;

  /// Opened from the result screen: pop with the recalculated verification
  /// instead of replacing the route.
  final bool returnToResult;
}

/// Where a prefilled value came from (drives the badge).
enum RateOrigin { statement, cardRule, previous, none }

/// Editable state of one rate entry (the base rate or one category).
class RateEntryDraft {
  RateEntryDraft({
    required this.categoryId,
    required this.name,
    required this.origin,
    required this.required,
    this.evidence,
    this.unitNote,
    String rate = '',
    String cap = '',
  }) : rate = TextEditingController(text: rate),
       cap = TextEditingController(text: cap);

  /// Null for the base rate.
  final String? categoryId;
  final String name;
  final RateOrigin origin;
  final String? evidence;
  final String? unitNote;
  final TextEditingController rate;
  final TextEditingController cap;

  /// No value to prefill: the user must type one. Also set when the server
  /// answers `RATES_REQUIRED` for this entry.
  bool required;

  /// The user interacted with the field (inline errors show from then on).
  bool touched = false;

  bool get isBase => categoryId == null;

  /// The base rate always needs a value; a category only when required.
  bool get mustHaveRate => isBase || required;

  bool get hasRate => rate.text.trim().isNotEmpty;

  /// Inline error for the rate field, or `null` when valid.
  String? get rateError {
    if (!hasRate) return mustHaveRate ? S.rateRequiredError : null;
    return CardValidator.percent(rate.text);
  }

  String? get capError => isBase ? null : CardValidator.positiveCap(cap.text);

  bool get isValid => rateError == null && capError == null;

  void dispose() {
    rate.dispose();
    cap.dispose();
  }
}

/// Step 2 of the verification flow: the user confirms or edits the rates and
/// the backend computes the audit. Also used to recalculate for free.
class ConfirmRatesController extends GetxController {
  ConfirmRatesController({
    required this._repository,
    required this._cards,
    required this._navigator,
    required this.args,
  });

  final VerificationRepository _repository;
  final CardsController _cards;
  final AppNavigator _navigator;
  final ConfirmRatesArgs args;

  final verification = Rxn<Verification>();
  final loading = false.obs;
  final submitting = false.obs;
  final errorMessage = RxnString();

  final entries = <RateEntryDraft>[].obs;
  final saveToCard = false.obs;
  final exchangeRate = TextEditingController();
  final reportedOverride = TextEditingController();

  /// Program names to choose from (several programs and none selected, or
  /// the server answered `REWARD_PROGRAM_AMBIGUOUS`).
  final programChoices = <String>[].obs;
  final selectedProgram = RxnString();

  /// The statement shows no usable reward figure: the user types it.
  final needsReportedOverride = false.obs;

  /// Bumped on every edit so `canConfirm` is reactive.
  final _revision = 0.obs;

  bool get isRecalculation => verification.value?.isCompleted ?? false;

  RewardUnit get unit {
    final v = verification.value;
    final card = v == null ? null : _cards.byId(v.cardId);
    return card?.rewardUnit ?? v?.unit ?? RewardUnit.cashbackCurrency;
  }

  String get primaryCurrency => verification.value?.currency ?? 'MXN';

  /// Exchange rate field only when foreign-currency purchases exist.
  bool get showExchangeRate => verification.value?.hasForeignPurchases ?? false;

  StatementRate? get statementRate =>
      verification.value?.conversion.statementRate;

  /// True when foreign purchases would be left out of the calculation.
  bool get foreignWillBeExcluded =>
      showExchangeRate &&
      statementRate == null &&
      exchangeRate.text.trim().isEmpty;

  String? get exchangeRateError {
    final t = exchangeRate.text.trim();
    if (t.isEmpty) return null;
    final d = CardValidator.parse(t);
    if (d == null || d <= Decimal.zero || d.scale > 6) {
      return S.exchangeRateInvalid;
    }
    return null;
  }

  String? get overrideError {
    if (!needsReportedOverride.value) return null;
    final t = reportedOverride.text.trim();
    final d = CardValidator.parse(t);
    if (d == null || d < Decimal.zero || d.scale > 2) return S.overrideInvalid;
    return null;
  }

  /// All required fields are filled and valid.
  bool get canConfirm {
    _revision.value; // reactive dependency
    if (verification.value == null || submitting.value) return false;
    if (entries.isEmpty || !entries.every((e) => e.isValid)) return false;
    if (exchangeRateError != null) return false;
    if (programChoices.isNotEmpty && selectedProgram.value == null) {
      return false;
    }
    return overrideError == null;
  }

  @override
  void onInit() {
    super.onInit();
    final v = args.verification;
    if (v != null) {
      _load(v);
    } else {
      fetch();
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (!_cards.loaded.value) _cards.load();
  }

  Future<void> fetch() async {
    loading.value = true;
    errorMessage.value = null;
    try {
      _load((await _repository.detail(args.verificationId!)).data);
    } on AppException catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = false;
    }
  }

  void _load(Verification v) {
    verification.value = v;
    for (final e in entries) {
      e.dispose();
    }
    entries.assignAll(buildEntries(v));
    for (final e in entries) {
      e.rate.addListener(_bump);
      e.cap.addListener(_bump);
    }
    exchangeRate.removeListener(_bump);
    exchangeRate.addListener(_bump);
    reportedOverride.removeListener(_bump);
    reportedOverride.addListener(_bump);
    final requested = v.conversion.requestedRate;
    exchangeRate.text = requested == null ? '' : decimalToApi(requested);
    programChoices.assignAll(
      v.loyalty.needsChoice ? v.loyalty.programs.map((p) => p.name) : const [],
    );
    selectedProgram.value = null;
    _bump();
  }

  void _bump() => _revision.value++;

  /// Prefill priority: rates the verification was audited with (recalc) >
  /// what the statement states > the card's rule > empty and required.
  @visibleForTesting
  static List<RateEntryDraft> buildEntries(Verification v) {
    final applied = v.appliedRates;
    final drafts = <RateEntryDraft>[];
    for (final p in v.rateProposal) {
      final appliedRate = p.isBase
          ? applied?.baseRatePercent
          : applied?.categoryRates
                .where((r) => r.categoryId == p.categoryId)
                .map((r) => r.ratePercent)
                .firstOrNull;
      final appliedCap = p.isBase
          ? null
          : applied?.categoryRates
                .where((r) => r.categoryId == p.categoryId)
                .map((r) => r.monthlyCap)
                .firstOrNull;
      final Decimal? value = appliedRate ?? p.ratePercent;
      final origin = appliedRate != null
          ? RateOrigin.previous
          : switch (p.source) {
              RateSource.statement when value != null => RateOrigin.statement,
              RateSource.cardRule when value != null => RateOrigin.cardRule,
              _ => RateOrigin.none,
            };
      final cap = appliedRate != null ? appliedCap : p.monthlyCap;
      drafts.add(
        RateEntryDraft(
          categoryId: p.categoryId,
          name: p.isBase ? S.rateBaseTitle : (p.categoryName ?? ''),
          origin: origin,
          required:
              value == null && (p.required || p.source == RateSource.none),
          evidence: p.source == RateSource.statement ? p.evidence : null,
          unitNote: p.source == RateSource.statement ? p.unitNote : null,
          rate: value == null ? '' : decimalToApi(value),
          cap: cap == null ? '' : decimalToApi(cap),
        ),
      );
    }
    // A completed verification always has a base entry in its proposal; if a
    // legacy row has none, still let the user set the base rate.
    if (!drafts.any((d) => d.isBase)) {
      drafts.insert(
        0,
        RateEntryDraft(
          categoryId: null,
          name: S.rateBaseTitle,
          origin: applied == null ? RateOrigin.none : RateOrigin.previous,
          required: applied == null,
          rate: applied == null ? '' : decimalToApi(applied.baseRatePercent),
        ),
      );
    }
    drafts.sort((a, b) => a.isBase == b.isBase ? 0 : (a.isBase ? -1 : 1));
    return drafts;
  }

  void touch(RateEntryDraft entry) {
    entry.touched = true;
    _bump();
  }

  void selectProgram(String? name) {
    selectedProgram.value = name;
    _bump();
  }

  void setSaveToCard(bool value) => saveToCard.value = value;

  /// Builds the request from the current inputs. Entries without a value
  /// (optional categories left blank) are omitted: they audit at the base.
  ConfirmRequest buildRequest() {
    final base = entries.firstWhere((e) => e.isBase);
    final exchange = CardValidator.parse(exchangeRate.text);
    return ConfirmRequest(
      baseRatePercent: CardValidator.parse(base.rate.text)!,
      categoryRates: [
        for (final e in entries)
          if (!e.isBase && e.hasRate)
            CategoryRateInput(
              categoryId: e.categoryId!,
              ratePercent: CardValidator.parse(e.rate.text)!,
              monthlyCap: CardValidator.parse(e.cap.text),
            ),
      ],
      saveToCard: saveToCard.value,
      reportedRewardOverride: needsReportedOverride.value
          ? CardValidator.parse(reportedOverride.text)
          : null,
      exchangeRate: showExchangeRate ? exchange : null,
      rewardProgramName: selectedProgram.value,
    );
  }

  Future<void> confirm() async {
    final v = verification.value;
    if (v == null || !canConfirm) return;
    submitting.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.confirm(v.id, buildRequest());
      if (saveToCard.value) _cards.load();
      if (args.returnToResult) {
        _navigator.pop(result: result);
      } else {
        _navigator.replace(Routes.result, arguments: result);
      }
    } on AppException catch (e) {
      _handleError(e);
    } finally {
      submitting.value = false;
    }
  }

  void _handleError(AppException e) {
    switch (e.code) {
      case 'REWARD_PROGRAM_AMBIGUOUS':
        final programs = _stringList((e.details as Map?)?['programs']);
        if (programs.isNotEmpty) {
          programChoices.assignAll(programs);
          selectedProgram.value = null;
        }
        errorMessage.value = userMessageFor(e);
      case 'REPORTED_REWARD_NOT_FOUND':
        needsReportedOverride.value = true;
        errorMessage.value = userMessageFor(e);
      case 'RATES_REQUIRED':
        final missing = ((e.details as Map?)?['missing'] as List?) ?? const [];
        final ids = {
          for (final m in missing)
            if (m is Map) m['categoryId'] as String?,
        };
        for (final entry in entries) {
          if (ids.contains(entry.categoryId)) {
            entry.required = true;
            entry.touched = true;
          }
        }
        entries.refresh();
        errorMessage.value = userMessageFor(e);
      default:
        errorMessage.value = userMessageFor(e);
    }
    _bump();
  }

  static List<String> _stringList(Object? v) =>
      v is List ? [for (final e in v) e.toString()] : const [];

  @override
  void onClose() {
    for (final e in entries) {
      e.dispose();
    }
    exchangeRate.dispose();
    reportedOverride.dispose();
    super.onClose();
  }
}
