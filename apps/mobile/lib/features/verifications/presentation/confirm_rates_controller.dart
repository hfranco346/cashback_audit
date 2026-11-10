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
import '../../categories/presentation/catalog_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../domain/verification_entities.dart';
import '../domain/verification_repository.dart';
import 'delete_verification.dart';

/// Where the confirmation screen gets its verification from and where it
/// goes afterwards.
class ConfirmRatesArgs {
  /// Fresh step-1 result (upload) or a completed one being recalculated.
  const ConfirmRatesArgs.verification(
    Verification this.verification, {
    this.returnToResult = false,
  }) : verificationId = null;

  /// Resume from history: the detail is fetched.
  const ConfirmRatesArgs.byId(
    String this.verificationId, {
    this.returnToResult = false,
  }) : verification = null;

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

/// `null` when [text] is a valid exchange rate (> 0, at most 6 decimals).
String? validateExchangeRate(String text) {
  final d = CardValidator.parse(text);
  if (d == null || d <= Decimal.zero || d.scale > 6) {
    return S.exchangeRateInvalid;
  }
  return null;
}

/// Editable optional rate for one foreign spend currency.
class ForeignRateDraft {
  ForeignRateDraft({
    required this.currency,
    required this.origin,
    String rate = '',
  }) : rate = TextEditingController(text: rate);

  final String currency;
  final RateOrigin origin;
  final TextEditingController rate;

  bool get hasRate => rate.text.trim().isNotEmpty;

  /// Optional: only validated when something was typed.
  String? get error => hasRate ? validateExchangeRate(rate.text) : null;

  /// Without a rate this currency's purchases are left out of the audit.
  bool get willBeExcluded => !hasRate;

  void dispose() => rate.dispose();
}

/// Step 2 of the verification flow: the user confirms or edits the rates and
/// the backend computes the audit. Also used to recalculate for free.
class ConfirmRatesController extends GetxController {
  ConfirmRatesController({
    required this._repository,
    required this._cards,
    required this._navigator,
    required this.args,
    this._catalog,
    this.credits,
    this.savedRates = const {},
    this.savedRatesPrimary,
  });

  final VerificationRepository _repository;
  final CardsController _cards;
  final AppNavigator _navigator;
  final CatalogController? _catalog;
  final CreditsController? credits;
  final ConfirmRatesArgs args;

  /// The user's last rate per currency (`AppUser.currencyRates`), expressed
  /// in [savedRatesPrimary] units. Suggested when nothing better exists.
  final Map<String, Decimal> savedRates;
  final String? savedRatesPrimary;

  final verification = Rxn<Verification>();
  final loading = false.obs;
  final submitting = false.obs;
  final errorMessage = RxnString();

  final entries = <RateEntryDraft>[].obs;
  final saveToCard = false.obs;
  final exchangeRate = TextEditingController();

  /// Reward currency differs from the card's: the user types how much one
  /// unit of it is worth (primary units).
  final rewardConversion = Rxn<RewardConversion>();
  final rewardRate = TextEditingController();
  RateOrigin rewardRateOrigin = RateOrigin.none;
  bool rewardRateTouched = false;

  /// One optional rate per foreign spend currency.
  final foreignRates = <ForeignRateDraft>[].obs;

  /// Statement categories the user lacks, those ticked and progress.
  final suggestions = <SuggestedCategory>[].obs;
  final selectedSuggestions = <String>{}.obs;
  final creatingSuggestions = false.obs;
  final suggestionsCreatedNotice = false.obs;
  final _handledSuggestions = <String>{};
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

  /// The card being audited, once the cards are loaded.
  CreditCard? get card {
    final v = verification.value;
    return v == null ? null : _cards.byId(v.cardId);
  }

  String get primaryCurrency => verification.value?.currency ?? 'MXN';

  /// The old single "any foreign currency" field: only for verifications
  /// without a per-currency proposal (rows from before it existed).
  bool get showExchangeRate =>
      (verification.value?.hasForeignPurchases ?? false) &&
      foreignRates.isEmpty;

  StatementRate? get statementRate =>
      verification.value?.conversion.statementRate;

  /// True when foreign purchases would be left out of the calculation.
  bool get foreignWillBeExcluded =>
      showExchangeRate &&
      statementRate == null &&
      exchangeRate.text.trim().isEmpty;

  String? get exchangeRateError {
    final t = exchangeRate.text.trim();
    return t.isEmpty ? null : validateExchangeRate(t);
  }

  /// The server reuses the spend rate of the reward currency when no reward
  /// rate is sent, so a valid one there also satisfies the reward conversion.
  bool get _rewardRateCoveredBySpendRate {
    final to = rewardConversion.value?.toCurrency;
    return foreignRates.any(
      (f) => f.currency == to && f.hasRate && f.error == null,
    );
  }

  /// Required while empty (unless covered), valid when filled.
  String? get rewardRateError {
    final conv = rewardConversion.value;
    if (conv == null) return null;
    final t = rewardRate.text.trim();
    if (t.isEmpty) {
      return conv.required && !_rewardRateCoveredBySpendRate
          ? S.rewardRateRequiredError
          : null;
    }
    return validateExchangeRate(t);
  }

  String? get overrideError {
    if (!needsReportedOverride.value) return null;
    final t = reportedOverride.text.trim();
    final d = CardValidator.parse(t);
    if (d == null || d < Decimal.zero || d.scale > 2) return S.overrideInvalid;
    return null;
  }

  /// Name of the program that will be audited (single or chosen), if known.
  String? get programName {
    final loyalty = verification.value?.loyalty;
    return selectedProgram.value ??
        loyalty?.selectedProgram?.name ??
        (loyalty != null && loyalty.programs.length == 1
            ? loyalty.programs.first.name
            : null);
  }

  /// Labels of the required fields still empty (drives the footer hint).
  List<String> get missingFields {
    _revision.value; // reactive dependency
    return [
      for (final e in entries)
        if (e.mustHaveRate && !e.hasRate) e.name,
      if (rewardConversion.value != null &&
          rewardRate.text.trim().isEmpty &&
          rewardRateError != null)
        S.current.exchangeRewardTitle,
      if (programChoices.isNotEmpty && selectedProgram.value == null)
        S.current.programChooserTitle,
      if (needsReportedOverride.value && reportedOverride.text.trim().isEmpty)
        S.current.overrideLabel,
    ];
  }

  /// Labels of the filled fields with an invalid value.
  List<String> get invalidFields {
    _revision.value; // reactive dependency
    return [
      for (final e in entries)
        if (e.hasRate && !e.isValid) e.name,
      if (rewardConversion.value != null &&
          rewardRate.text.trim().isNotEmpty &&
          rewardRateError != null)
        S.current.exchangeRewardTitle,
      for (final f in foreignRates)
        if (f.error != null) S.current.exchangeForeignTitle(f.currency),
      if (exchangeRateError != null) S.current.exchangeRateTitle,
      if (needsReportedOverride.value &&
          reportedOverride.text.trim().isNotEmpty &&
          overrideError != null)
        S.current.overrideLabel,
    ];
  }

  /// All required fields are filled and valid.
  bool get canConfirm {
    _revision.value; // reactive dependency
    if (verification.value == null || submitting.value) return false;
    if (entries.isEmpty || !entries.every((e) => e.isValid)) return false;
    if (exchangeRateError != null || rewardRateError != null) return false;
    if (!foreignRates.every((f) => f.error == null)) return false;
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
    rewardRate.removeListener(_bump);
    rewardRate.addListener(_bump);
    _loadConversion(v);
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

  /// Prefill priority for the reward and foreign rates: what the
  /// verification was audited with / sent before > what the statement prints
  /// > empty.
  void _loadConversion(Verification v) {
    final conv = v.rewardConversion;
    rewardConversion.value = conv;
    final used =
        v.appliedRates?.rewardExchangeRate?.rate ??
        v.conversion.requestedRewardRate;
    final saved = conv == null
        ? null
        : _savedRate(code: conv.toCurrency, target: conv.fromCurrency);
    final reward = used ?? conv?.rate ?? saved;
    rewardRate.text = reward == null ? '' : decimalToApi(reward);
    rewardRateOrigin = (used != null || (conv?.rate == null && saved != null))
        ? RateOrigin.previous
        : (conv?.rate != null ? RateOrigin.statement : RateOrigin.none);
    rewardRateTouched = false;

    for (final f in foreignRates) {
      f.dispose();
    }
    foreignRates.assignAll([
      for (final e in v.exchangeRateProposal)
        () {
          final sent = v.conversion.requestedRates[e.currency];
          final saved = _savedRate(code: e.currency, target: v.currency);
          final value = sent ?? e.rate ?? saved;
          final draft = ForeignRateDraft(
            currency: e.currency,
            origin: sent != null || (e.rate == null && saved != null)
                ? RateOrigin.previous
                : (e.rate != null ? RateOrigin.statement : RateOrigin.none),
            rate: value == null ? '' : decimalToApi(value),
          );
          draft.rate.addListener(_bump);
          return draft;
        }(),
    ]);

    _handledSuggestions.clear();
    suggestionsCreatedNotice.value = false;
    _loadSuggestions(v, preselect: true);
  }

  /// The user's saved rate for [code] when it is expressed in [target].
  Decimal? _savedRate({required String code, required String target}) =>
      savedRatesPrimary == target ? savedRates[code] : null;

  void _loadSuggestions(Verification v, {required bool preselect}) {
    final visible = [
      for (final s in v.suggestedCategories)
        if (!_handledSuggestions.contains(s.name)) s,
    ];
    suggestions.assignAll(visible);
    final names = visible.map((s) => s.name).toSet();
    selectedSuggestions.removeWhere((n) => !names.contains(n));
    if (preselect) {
      // Names that matched at least one line are the likely wanted ones.
      selectedSuggestions.assignAll({
        for (final s in visible)
          if (s.matchingTransactionCount >= 1) s.name,
      });
    }
  }

  void touchRewardRate() {
    rewardRateTouched = true;
    _bump();
  }

  void toggleSuggestion(String name, bool selected) {
    if (selected) {
      selectedSuggestions.add(name);
    } else {
      selectedSuggestions.remove(name);
    }
  }

  /// Creates the ticked categories (free) and refreshes the proposal in
  /// place, keeping everything the user already typed.
  Future<void> createSuggestedCategories() async {
    final v = verification.value;
    if (v == null || creatingSuggestions.value) return;
    final names = [
      for (final s in suggestions)
        if (selectedSuggestions.contains(s.name)) s.name,
    ];
    if (names.isEmpty) return;
    creatingSuggestions.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.createCategoriesFromSuggestions(
        v.id,
        names,
      );
      _handledSuggestions.addAll(names);
      _mergeRefreshed(updated);
      suggestionsCreatedNotice.value = true;
      _catalog?.load();
    } on AppException catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      creatingSuggestions.value = false;
    }
  }

  /// Takes a refreshed proposal without losing the user's edits: existing
  /// rate entries stay as they are, new categories are added prefilled.
  void _mergeRefreshed(Verification v) {
    verification.value = v;
    final existing = {for (final e in entries) e.categoryId: e};
    final merged = <RateEntryDraft>[];
    for (final fresh in buildEntries(v)) {
      final old = existing.remove(fresh.categoryId);
      if (old != null) {
        fresh.dispose();
        merged.add(old);
      } else {
        fresh.rate.addListener(_bump);
        fresh.cap.addListener(_bump);
        merged.add(fresh);
      }
    }
    for (final dropped in existing.values) {
      dropped.dispose();
    }
    entries.assignAll(merged);
    _loadSuggestions(v, preselect: false);
    _bump();
  }

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
      exchangeRates: {
        for (final f in foreignRates)
          if (f.hasRate) f.currency: CardValidator.parse(f.rate.text)!,
      },
      rewardExchangeRate: rewardConversion.value == null
          ? null
          : CardValidator.parse(rewardRate.text),
      rewardProgramName: selectedProgram.value,
    );
  }

  /// Deleting is offered for a statement still waiting for its rates (the
  /// user abandons it); a recalculation is deleted from the result screen.
  bool get canDelete => !args.returnToResult && verification.value != null;

  bool get deleteLosesCreditNote =>
      deleteLosesCredit(credits: credits, status: verification.value?.status);

  /// Deletes this verification (already confirmed by the user) and goes
  /// back with a snackbar. Returns the error message, or `null` on success.
  Future<String?> deleteVerification() async {
    final id = verification.value?.id ?? args.verificationId;
    if (id == null || submitting.value) return null;
    submitting.value = true;
    try {
      final error = await deleteVerificationById(_repository, id);
      if (error != null) return error;
      _navigator.pop();
      _navigator.showNotice(S.current.deleteVerificationDone, '');
      return null;
    } finally {
      submitting.value = false;
    }
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
      case 'REWARD_EXCHANGE_RATE_REQUIRED':
        // The server could not find a rate: make the field required (and
        // create it when the proposal did not announce a conversion).
        final d = e.details is Map ? e.details as Map : const {};
        final current = rewardConversion.value;
        final from = (d['fromCurrency'] ?? current?.fromCurrency) as String?;
        final to = (d['toCurrency'] ?? current?.toCurrency) as String?;
        if (from != null && to != null) {
          rewardConversion.value = RewardConversion(
            fromCurrency: from,
            toCurrency: to,
            rate: current?.rate,
            fromStatement: current?.fromStatement ?? false,
            required: true,
            note: current?.note,
          );
        }
        rewardRateTouched = true;
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
    rewardRate.dispose();
    for (final f in foreignRates) {
      f.dispose();
    }
    reportedOverride.dispose();
    super.onClose();
  }
}
