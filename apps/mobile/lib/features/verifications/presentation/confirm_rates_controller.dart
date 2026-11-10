import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../../core/utils/rate_direction.dart';
import '../../cards/domain/card_entities.dart';
import '../../cards/domain/card_validator.dart';
import '../../cards/presentation/cards_controller.dart';
import '../../categories/presentation/catalog_controller.dart';
import '../../credits/presentation/credits_controller.dart';
import '../domain/pdf_picker.dart';
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

/// Where a prefilled value came from (drives the badge). [lastRate] is the
/// user's saved exchange rate for the currency.
enum RateOrigin { statement, cardRule, previous, lastRate, none }

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
/// With a [direction] the API value derived from it must also be valid.
String? validateExchangeRate(String text, {RateDirection? direction}) {
  final d = CardValidator.parse(text);
  if (d == null || d <= Decimal.zero || d.scale > 6) {
    return S.exchangeRateInvalid;
  }
  if (direction != null && direction.toStored(d) == null) {
    return S.exchangeRateInvalid;
  }
  return null;
}

/// Editable optional rate for one foreign spend currency.
class ForeignRateDraft {
  ForeignRateDraft({
    required this.currency,
    required this.origin,
    required this.direction,
    this.previewAmount,
    String rate = '',
  }) : rate = TextEditingController(text: rate);

  final String currency;
  final RateOrigin origin;

  /// Which currency is the unit of the question; [rate] holds the number as
  /// the user sees it, [apiRate] converts it to the API direction.
  final RateDirection direction;

  /// Net purchases in [currency] (preview of the effect), when known.
  final Decimal? previewAmount;
  final TextEditingController rate;

  /// The value to send (`primary units per 1 [currency]`), or `null`.
  Decimal? get apiRate {
    final shown = CardValidator.parse(rate.text);
    return shown == null ? null : direction.toStored(shown);
  }

  bool get hasRate => rate.text.trim().isNotEmpty;

  /// Optional: only validated when something was typed.
  String? get error =>
      hasRate ? validateExchangeRate(rate.text, direction: direction) : null;

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
    this._picker,
    this.credits,
    this.savedRates = const {},
    this.savedRatesPrimary,
  });

  final VerificationRepository _repository;
  final CardsController _cards;
  final AppNavigator _navigator;
  final CatalogController? _catalog;
  final PdfPicker? _picker;
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

  /// Unit of the reward question and API conversion (set with
  /// [rewardConversion]); [rewardRate] holds the number as the user sees it.
  RateDirection? rewardDirection;

  /// The bank-reported reward in the reward currency (preview), if known.
  Decimal? rewardPreviewAmount;
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

  /// Details (unit, currency, printed label) of each choice, by name.
  final programOptions = <String, RewardProgramOption>{}.obs;

  /// Save the chosen program on the card.
  final rememberProgram = false.obs;

  /// The statement shows no usable reward figure: the user types it.
  final needsReportedOverride = false.obs;

  /// How the bank's reward figure is reported: the section is shown while a
  /// proposal exists (or the server asked for the previous balance).
  final reportingProposal = Rxn<RewardReportingProposal>();
  final reportingMode = RewardReporting.monthly.obs;
  final rememberReporting = false.obs;
  final previousBalance = TextEditingController();
  final previousBalanceSource = Rxn<PreviousBalanceSource>();
  final uploadingPrevious = false.obs;
  final previousUploadProgress = 0.0.obs;
  final previousUploadError = RxnString();

  /// Programs read from last month's PDF when none matched (pick one).
  final previousProgramChoices = <PreviousStatementProgram>[].obs;
  bool _serverWantsPreviousBalance = false;
  bool _settingPrevious = false;

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

  /// Currency of the reward figures (the reward currency when it differs
  /// from the card's, as the conversion card asks).
  String get rewardDisplayCurrency =>
      rewardConversion.value?.toCurrency ??
      verification.value?.resolvedRewardCurrency ??
      primaryCurrency;

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
    return validateExchangeRate(t, direction: rewardDirection);
  }

  String? get overrideError {
    if (!needsReportedOverride.value) return null;
    final t = reportedOverride.text.trim();
    final d = CardValidator.parse(t);
    if (d == null || d < Decimal.zero || d.scale > 2) return S.overrideInvalid;
    return null;
  }

  bool get canUploadPrevious => _picker != null;

  bool get showReporting => reportingProposal.value != null;

  bool get isCumulative => reportingMode.value == RewardReporting.cumulative;

  /// The previous balance as a number, `null` when empty or not numeric.
  Decimal? get previousBalanceValue =>
      CardValidator.parse(previousBalance.text);

  /// Inline error of a filled previous balance (0 or more, up to 2 decimals).
  String? get previousBalanceError {
    if (previousBalance.text.trim().isEmpty) return null;
    final d = previousBalanceValue;
    return d == null || d < Decimal.zero || d.scale > 2
        ? S.overrideInvalid
        : null;
  }

  /// A cumulative figure needs the previous balance unless the statement
  /// already gives what was earned.
  bool get previousBalanceRequired {
    _revision.value; // reactive dependency
    final p = reportingProposal.value;
    if (p == null || !isCumulative) return false;
    if (previousBalance.text.trim().isNotEmpty) return false;
    return _serverWantsPreviousBalance || p.earned == null;
  }

  /// What was earned this month, live: from the typed previous balance, or
  /// the amount the statement itself prints.
  Decimal? get liveEarned {
    _revision.value; // reactive dependency
    final p = reportingProposal.value;
    if (p == null || !isCumulative) return null;
    final previous = previousBalanceValue;
    if (previous == null || previousBalanceError != null) {
      return previousBalance.text.trim().isEmpty ? p.earned : null;
    }
    return deriveEarned(
      current: p.currentBalance,
      previous: previous,
      redeemed: p.redeemedInPeriod,
      expired: p.expiredInPeriod,
    );
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
      if (previousBalanceRequired) S.current.reportingPreviousLabel,
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
      if (isCumulative && previousBalanceError != null)
        S.current.reportingPreviousLabel,
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
    if (uploadingPrevious.value) return false;
    if (previousBalanceRequired) return false;
    if (isCumulative && previousBalanceError != null) return false;
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
    previousBalance.removeListener(_onPreviousEdited);
    previousBalance.addListener(_onPreviousEdited);
    _loadReporting(v);
    final requested = v.conversion.requestedRate;
    exchangeRate.text = requested == null ? '' : decimalToApi(requested);
    final choice = v.rewardProgramChoice;
    if (choice != null && choice.required && choice.options.isNotEmpty) {
      programOptions.assignAll({for (final o in choice.options) o.name: o});
      programChoices.assignAll(choice.options.map((o) => o.name));
    } else {
      programOptions.clear();
      programChoices.assignAll(
        v.loyalty.needsChoice
            ? v.loyalty.programs.map((p) => p.name)
            : const [],
      );
    }
    selectedProgram.value = null;
    rememberProgram.value = false;
    _bump();
  }

  void _bump() => _revision.value++;

  /// Preselects the mode the backend proposes and prefills the previous
  /// balance it resolved. A completed verification being recalculated keeps
  /// its cumulative derivation (and can switch it).
  void _loadReporting(Verification v) {
    final proposal = v.rewardReportingProposal ?? _proposalFromResult(v);
    reportingProposal.value = proposal;
    _serverWantsPreviousBalance = false;
    previousUploadError.value = null;
    previousProgramChoices.clear();
    uploadingPrevious.value = false;
    rememberReporting.value = false;
    reportingMode.value = proposal?.mode ?? RewardReporting.monthly;
    final previous = proposal?.previousBalance;
    _setPrevious(
      previous == null ? '' : decimalToApi(previous),
      previous == null ? null : proposal?.previousBalanceSource,
    );
  }

  static RewardReportingProposal? _proposalFromResult(Verification v) {
    final r = v.rewardReporting;
    if (!v.isCompleted || r == null || !r.isCumulative) return null;
    return RewardReportingProposal(
      mode: RewardReporting.cumulative,
      suggestedMode: RewardReporting.cumulative,
      reason: ReportingReason.none,
      currentBalance: r.currentBalance,
      previousBalance: r.previousBalance,
      previousBalanceSource: r.previousBalanceSource,
      redeemedInPeriod: r.redeemedInPeriod,
      expiredInPeriod: r.expiredInPeriod,
      earned: r.earned,
      programName: v.reported?.label,
    );
  }

  void _setPrevious(String text, PreviousBalanceSource? source) {
    _settingPrevious = true;
    previousBalance.text = text;
    _settingPrevious = false;
    previousBalanceSource.value = text.trim().isEmpty ? null : source;
    _bump();
  }

  /// Typing replaces whatever source the value had.
  void _onPreviousEdited() {
    if (!_settingPrevious) {
      previousBalanceSource.value = previousBalance.text.trim().isEmpty
          ? null
          : PreviousBalanceSource.user;
    }
    _bump();
  }

  /// The user picks "earned this month" or "accumulated balance". Changing
  /// the proposed answer turns "remember for this card" on (they can undo).
  void setReportingMode(RewardReporting mode) {
    if (mode == RewardReporting.auto) return;
    reportingMode.value = mode;
    rememberReporting.value = mode != reportingProposal.value?.mode;
    _bump();
  }

  void setRememberReporting(bool value) => rememberReporting.value = value;

  void touchPreviousBalance() => _bump();

  /// Free: reads only the program balance of last month's PDF. A matched
  /// balance fills the field; otherwise the user picks the program.
  Future<void> pickPreviousStatement() async {
    final picker = _picker;
    final v = verification.value;
    if (picker == null || v == null || uploadingPrevious.value) return;
    final picked = await picker.pick();
    if (picked == null) return;
    if (!picked.name.toLowerCase().endsWith('.pdf')) {
      previousUploadError.value = S.fileNotPdf;
      return;
    }
    if (picked.sizeBytes > maxPdfBytes) {
      previousUploadError.value = S.fileTooLarge;
      return;
    }
    previousUploadError.value = null;
    previousProgramChoices.clear();
    previousUploadProgress.value = 0;
    uploadingPrevious.value = true;
    _bump();
    try {
      final result = await _repository.readPreviousStatement(
        v.id,
        filePath: picked.path,
        onProgress: (sent, total) {
          if (total > 0) previousUploadProgress.value = sent / total;
        },
      );
      final matched = result.matchedBalance;
      if (matched != null) {
        _setPrevious(
          decimalToApi(matched),
          PreviousBalanceSource.previousStatement,
        );
      } else if (result.programs.isNotEmpty) {
        previousProgramChoices.assignAll(result.programs);
      } else {
        previousUploadError.value = S.errProgramNotFound;
      }
    } on AppException catch (e) {
      previousUploadError.value = userMessageFor(e);
    } finally {
      uploadingPrevious.value = false;
      _bump();
    }
  }

  void choosePreviousProgram(PreviousStatementProgram program) {
    previousProgramChoices.clear();
    _setPrevious(
      decimalToApi(program.balance),
      PreviousBalanceSource.previousStatement,
    );
  }

  static const maxPdfBytes = 10 * 1024 * 1024;

  RewardReportingInput? _reportingInput() {
    if (reportingProposal.value == null) return null;
    if (!isCumulative) {
      return RewardReportingInput(
        mode: RewardReporting.monthly,
        rememberForCard: rememberReporting.value,
      );
    }
    final previous = previousBalanceValue;
    return RewardReportingInput(
      mode: RewardReporting.cumulative,
      previousBalance: previous,
      previousBalanceSource: previous == null
          ? null
          : (previousBalanceSource.value ?? PreviousBalanceSource.user),
      rememberForCard: rememberReporting.value,
    );
  }

  /// Prefill priority for the reward and foreign rates: what the
  /// verification was audited with / sent before > what the statement prints
  /// > the user's last saved rate > empty. The stored value (API direction)
  /// also decides which currency is the unit of the question; the field
  /// shows it in that direction.
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
    rewardDirection = conv == null
        ? null
        : RateDirection.choose(
            primary: conv.fromCurrency,
            other: conv.toCurrency,
            knownStored: reward,
          );
    rewardRate.text = reward == null
        ? ''
        : decimalToApi(rewardDirection!.toShown(reward));
    rewardRateOrigin = used != null
        ? RateOrigin.previous
        : conv?.rate != null
        ? RateOrigin.statement
        : saved != null
        ? RateOrigin.lastRate
        : RateOrigin.none;
    rewardRateTouched = false;
    final reported = v.reported;
    rewardPreviewAmount =
        conv != null &&
            reported != null &&
            reported.unit != RewardUnit.points &&
            (reported.currency ?? conv.toCurrency) == conv.toCurrency
        ? reported.amount
        : null;

    for (final f in foreignRates) {
      f.dispose();
    }
    foreignRates.assignAll([
      for (final e in v.exchangeRateProposal)
        () {
          final sent = v.conversion.requestedRates[e.currency];
          final saved = _savedRate(code: e.currency, target: v.currency);
          final value = sent ?? e.rate ?? saved;
          final direction = RateDirection.choose(
            primary: v.currency,
            other: e.currency,
            knownStored: value,
          );
          final draft = ForeignRateDraft(
            currency: e.currency,
            direction: direction,
            previewAmount: _netPurchases(v, e.currency),
            origin: sent != null
                ? RateOrigin.previous
                : e.rate != null
                ? RateOrigin.statement
                : saved != null
                ? RateOrigin.lastRate
                : RateOrigin.none,
            rate: value == null ? '' : decimalToApi(direction.toShown(value)),
          );
          draft.rate.addListener(_bump);
          return draft;
        }(),
    ]);

    _handledSuggestions.clear();
    suggestionsCreatedNotice.value = false;
    _loadSuggestions(v, preselect: true);
  }

  /// Purchases minus refunds in [currency] (what the rate converts), or
  /// `null` when there is nothing to convert.
  static Decimal? _netPurchases(Verification v, String currency) {
    var total = Decimal.zero;
    for (final t in v.transactions) {
      if (t.currency != currency || !t.kind.earnsReward) continue;
      total += t.isCredit ? -t.amount : t.amount;
    }
    return total > Decimal.zero ? total : null;
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

  void setRememberProgram(bool value) => rememberProgram.value = value;

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
          if (f.hasRate && f.apiRate != null) f.currency: f.apiRate!,
      },
      rewardExchangeRate: _rewardApiRate,
      rewardProgramName: selectedProgram.value,
      rememberProgramForCard:
          selectedProgram.value != null && rememberProgram.value,
      rewardReporting: _reportingInput(),
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

  /// The reward rate in the API direction (primary units per 1 reward
  /// unit), or `null` when there is no conversion or nothing valid typed.
  Decimal? get _rewardApiRate {
    final conv = rewardConversion.value;
    if (conv == null) return null;
    final shown = CardValidator.parse(rewardRate.text);
    if (shown == null) return null;
    return (rewardDirection ??
            RateDirection.choose(
              primary: conv.fromCurrency,
              other: conv.toCurrency,
            ))
        .toStored(shown);
  }

  Future<void> confirm() async {
    final v = verification.value;
    if (v == null || !canConfirm) return;
    submitting.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.confirm(v.id, buildRequest());
      if (saveToCard.value ||
          rememberReporting.value ||
          (selectedProgram.value != null && rememberProgram.value)) {
        _cards.load();
      }
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
      case 'REWARD_PROGRAM_AMBIGUOUS' || 'INVALID_REWARD_PROGRAM':
        final programs = _programNames((e.details as Map?)?['programs']);
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
          if (rewardDirection?.primary != from ||
              rewardDirection?.other != to) {
            rewardDirection = RateDirection.choose(
              primary: from,
              other: to,
              knownStored: current?.rate,
            );
          }
        }
        rewardRateTouched = true;
        errorMessage.value = userMessageFor(e);
      case 'PREVIOUS_BALANCE_REQUIRED':
        // Also covers servers whose proposal did not announce the question.
        reportingProposal.value ??= const RewardReportingProposal(
          mode: RewardReporting.cumulative,
          suggestedMode: RewardReporting.cumulative,
          previousBalanceRequired: true,
        );
        reportingMode.value = RewardReporting.cumulative;
        _serverWantsPreviousBalance = true;
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

  /// Program names from a list of strings or of `{name, ...}` objects.
  static List<String> _programNames(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) (e['name'] ?? '').toString() else e.toString(),
        ].where((n) => n.isNotEmpty).toList()
      : const [];

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
    previousBalance.dispose();
    super.onClose();
  }
}
