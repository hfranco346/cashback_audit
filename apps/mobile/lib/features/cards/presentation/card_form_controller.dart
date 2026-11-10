import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../categories/domain/catalog_entities.dart';
import '../../categories/presentation/catalog_controller.dart';
import '../domain/card_entities.dart';
import '../domain/card_repository.dart';
import '../domain/card_validator.dart';
import 'card_review_data.dart';
import 'cards_controller.dart';

/// Editable state of one reward rule row.
class RuleDraft {
  RuleDraft({this.categoryId, String rate = '', String cap = ''})
    : rate = TextEditingController(text: rate),
      cap = TextEditingController(text: cap);

  String? categoryId;
  final TextEditingController rate;
  final TextEditingController cap;

  void dispose() {
    rate.dispose();
    cap.dispose();
  }
}

class CardFormController extends GetxController {
  CardFormController({
    required this._repository,
    required this._cards,
    required this._catalog,
    this.editing,
    this.userCurrencies = const [],
    this.defaultCurrency,
  });

  final CardRepository _repository;
  final CardsController _cards;
  final CatalogController _catalog;

  /// Null when creating.
  final CreditCard? editing;

  /// The user's own currencies (`GET /me`), suggested before common ones.
  final List<String> userCurrencies;

  /// Preselected card currency when creating (the user's primary currency).
  final String? defaultCurrency;

  /// Networks offered as chips; anything else is "other" (free text).
  static const knownNetworks = ['Visa', 'Mastercard', 'Amex'];

  bool get isEditing => editing != null;

  /// Steps of the form: card, reward, categories and review.
  static const stepCount = 4;
  static const reviewStep = stepCount - 1;

  /// One form per input step (the review step has no inputs).
  final stepKeys = List.generate(reviewStep, (_) => GlobalKey<FormState>());
  final alias = TextEditingController();
  final bank = TextEditingController();
  final last4 = TextEditingController();
  final network = TextEditingController();
  final rewardCap = TextEditingController();
  final rewardCurrency = TextEditingController();
  final currency = TextEditingController(text: 'MXN');
  final pointsFactor = TextEditingController(text: '1');
  final baseRate = TextEditingController();

  final rewardUnit = RewardUnit.cashbackCurrency.obs;
  final rewardReporting = RewardReporting.auto.obs;
  final rules = <RuleDraft>[].obs;
  final submitting = false.obs;
  final deleting = false.obs;

  /// Current step (0-based) and the furthest one reached, which bounds free
  /// navigation while creating (editing can jump anywhere).
  final step = 0.obs;
  final maxStep = 0.obs;

  /// True when the last move went forward (drives the transition).
  bool movedForward = true;

  /// Steps whose fields already show validation errors.
  final validatedSteps = <int>{}.obs;

  /// The selected network chip: a known network, `other`, or null.
  final selectedNetwork = RxnString();
  final errorMessage = RxnString();

  /// Per-row rule errors keyed by row index (shown under the rule editor).
  final ruleErrors = <int, String>{}.obs;

  CatalogController get catalog => _catalog;

  @override
  void onInit() {
    super.onInit();
    final c = editing;
    if (c != null) {
      alias.text = c.alias;
      bank.text = c.bank;
      last4.text = c.last4;
      network.text = c.network ?? '';
      rewardCap.text = c.rewardCap == null ? '' : decimalToApi(c.rewardCap!);
      maxStep.value = reviewStep;
      rewardCurrency.text = c.rewardCurrency ?? '';
      currency.text = c.currency;
      pointsFactor.text = decimalToApi(c.pointsPerCurrencyUnit);
      baseRate.text = decimalToApi(c.baseRatePercent);
      rewardUnit.value = c.rewardUnit;
      rewardReporting.value = c.rewardReporting;
      selectedNetwork.value = _networkChipFor(network.text);
      rules.assignAll([
        for (final r in c.rules)
          RuleDraft(
            categoryId: r.categoryId,
            rate: decimalToApi(r.ratePercent),
            cap: r.monthlyCap == null ? '' : decimalToApi(r.monthlyCap!),
          ),
      ]);
    } else if (defaultCurrency != null) {
      currency.text = defaultCurrency!;
    }
  }

  static String? _networkChipFor(String value) {
    final t = value.trim().toLowerCase();
    if (t.isEmpty) return null;
    for (final n in knownNetworks) {
      if (n.toLowerCase() == t) return n;
    }
    return 'other';
  }

  /// Picks a known network; tapping the selected one clears it (optional).
  void pickNetwork(String name) {
    final clear = selectedNetwork.value == name;
    network.text = clear ? '' : name;
    selectedNetwork.value = clear ? null : name;
  }

  /// Switches to the free-text "other" network (or back to none).
  void pickOtherNetwork() {
    network.text = '';
    selectedNetwork.value = selectedNetwork.value == 'other' ? null : 'other';
  }

  @override
  void onReady() {
    super.onReady();
    if (!_catalog.loaded.value) _catalog.load();
  }

  void setUnit(RewardUnit unit) => rewardUnit.value = unit;

  void setRewardReporting(RewardReporting value) =>
      rewardReporting.value = value;

  /// Adds a rule row preselecting the first category not used yet (or none,
  /// so the user picks or creates one). Returns false at the 50-rule limit.
  bool addRule() {
    if (rules.length >= 50) return false;
    final used = rules.map((r) => r.categoryId).toSet();
    final free = _catalog.categories.firstWhereOrNull(
      (c) => !used.contains(c.id),
    );
    rules.add(RuleDraft(categoryId: free?.id));
    return true;
  }

  void removeRule(int index) {
    rules.removeAt(index).dispose();
    ruleErrors.clear();
  }

  void setRuleCategory(int index, String? categoryId) {
    rules[index].categoryId = categoryId;
    rules.refresh();
  }

  bool get _isPoints => rewardUnit.value == RewardUnit.points;

  /// Rule errors by row index, without touching the UI state.
  Map<int, String> _computeRuleErrors() {
    final errors = <int, String>{};
    final seen = <String>{};
    for (var i = 0; i < rules.length; i++) {
      final r = rules[i];
      if (r.categoryId == null) {
        errors[i] = S.ruleCategoryRequired;
      } else if (!seen.add(r.categoryId!)) {
        errors[i] = S.ruleDuplicateCategory;
      } else {
        final msg =
            CardValidator.percent(r.rate.text) ??
            CardValidator.positiveCap(r.cap.text);
        if (msg != null) errors[i] = msg;
      }
    }
    return errors;
  }

  /// Validates rule rows; returns true when all are valid.
  bool _validateRules() {
    final errors = _computeRuleErrors();
    ruleErrors.assignAll(errors);
    return errors.isEmpty;
  }

  /// Whether the fields of input step [i] are all valid (no UI effects).
  bool stepValid(int i) => switch (i) {
    0 =>
      CardValidator.required(alias.text) == null &&
          CardValidator.required(bank.text) == null &&
          CardValidator.last4(last4.text) == null &&
          CardValidator.currency(currency.text) == null &&
          network.text.trim().length <= 30,
    1 =>
      (_isPoints
                  ? CardValidator.pointsFactor(pointsFactor.text)
                  : CardValidator.optionalCurrency(rewardCurrency.text)) ==
              null &&
          CardValidator.positiveCap(rewardCap.text) == null,
    2 =>
      CardValidator.percent(baseRate.text) == null &&
          _computeRuleErrors().isEmpty,
    _ => true,
  };

  /// First input step with a problem, or null when the whole card is valid.
  int? firstInvalidStep() {
    for (var i = 0; i < reviewStep; i++) {
      if (!stepValid(i)) return i;
    }
    return null;
  }

  /// Validates step [i] and makes its fields show their errors.
  bool validateStep(int i) {
    validatedSteps.add(i);
    if (i < reviewStep) stepKeys[i].currentState?.validate();
    if (i == 2) _validateRules();
    return stepValid(i);
  }

  bool canJumpTo(int i) =>
      i >= 0 && i < stepCount && (isEditing || i <= maxStep.value);

  /// Moves to step [i] (the header tabs) when allowed.
  void goTo(int i) {
    if (!canJumpTo(i) || i == step.value) return;
    _setStep(i);
  }

  void _setStep(int i) {
    movedForward = i >= step.value;
    step.value = i;
    if (i > maxStep.value) maxStep.value = i;
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// "Next": only advances when the current step is valid.
  bool next() {
    if (step.value >= reviewStep) return false;
    if (!validateStep(step.value)) return false;
    _setStep(step.value + 1);
    return true;
  }

  void back() {
    if (step.value > 0) _setStep(step.value - 1);
  }

  /// Plain snapshot for the review step.
  CardReviewData review() {
    final points = _isPoints;
    final reward = rewardCurrency.text.trim().toUpperCase();
    final cap = rewardCap.text.trim();
    return CardReviewData(
      alias: alias.text.trim(),
      bank: bank.text.trim(),
      last4: last4.text.trim(),
      network: network.text.trim().isEmpty ? null : network.text.trim(),
      currency: currency.text.trim().toUpperCase(),
      unit: rewardUnit.value,
      pointsFactor: points ? pointsFactor.text.trim() : null,
      rewardCurrency: points || reward.isEmpty ? null : reward,
      reporting: rewardReporting.value,
      cap: cap.isEmpty ? null : cap,
      capUnit: capUnit,
      baseRate: baseRate.text.trim(),
      rules: [
        for (final r in rules)
          ReviewRule(
            name: _catalog.categoryById(r.categoryId)?.name ?? '',
            rate: r.rate.text.trim(),
            cap: r.cap.text.trim().isEmpty ? null : r.cap.text.trim(),
          ),
      ],
    );
  }

  /// Unit the card-wide cap is written in: `pts`, or the CARD currency (the
  /// same space as the per-rule caps, even when the reward is paid in
  /// another currency).
  String get capUnit => _isPoints ? 'pts' : currency.text.trim().toUpperCase();

  /// Builds the draft, or returns null (jumping to the first step with a
  /// problem) when something is invalid.
  CardDraft? buildDraft() {
    final bad = firstInvalidStep();
    if (bad != null) {
      validatedSteps.add(bad);
      if (bad == 2) _validateRules();
      _setStep(bad);
      return null;
    }
    final isPoints = _isPoints;
    final cap = rewardCap.text.trim();
    return CardDraft(
      alias: alias.text,
      bank: bank.text,
      last4: last4.text,
      network: network.text.trim().isEmpty ? null : network.text,
      // The program is chosen on the confirm screen now; an existing card
      // keeps whatever it already has.
      rewardProgramName: editing?.rewardProgramName,
      rewardCurrency: isPoints || rewardCurrency.text.trim().isEmpty
          ? null
          : rewardCurrency.text.trim().toUpperCase(),
      rewardUnit: rewardUnit.value,
      rewardReporting: rewardReporting.value,
      pointsPerCurrencyUnit: isPoints
          ? CardValidator.parse(pointsFactor.text)
          : null,
      baseRatePercent: CardValidator.parse(baseRate.text)!,
      currency: currency.text,
      rewardCap: cap.isEmpty ? null : CardValidator.parse(cap),
      rules: [
        for (final r in rules)
          RewardRule(
            categoryId: r.categoryId!,
            ratePercent: CardValidator.parse(r.rate.text)!,
            monthlyCap: CardValidator.parse(r.cap.text),
          ),
      ],
    );
  }

  /// Creates a category from the picker and returns it.
  Future<Category> createCategory(String name) =>
      _catalog.createCategoryReturning(name);

  /// Saves the card. Returns true on success.
  Future<bool> save() async {
    if (submitting.value) return false;
    final draft = buildDraft();
    if (draft == null) return false;
    submitting.value = true;
    errorMessage.value = null;
    try {
      if (isEditing) {
        await _repository.updateCard(editing!.id, draft);
      } else {
        await _repository.createCard(draft);
      }
      await _cards.load();
      return true;
    } on AppException catch (e) {
      errorMessage.value = userMessageFor(e);
      return false;
    } finally {
      submitting.value = false;
    }
  }

  /// Deletes the card being edited. Returns true on success; on failure
  /// [errorMessage] explains why.
  Future<bool> delete() async {
    final card = editing;
    if (card == null || deleting.value) return false;
    deleting.value = true;
    errorMessage.value = null;
    try {
      final message = await _cards.delete(card);
      if (message != null) {
        errorMessage.value = message;
        return false;
      }
      return true;
    } finally {
      deleting.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in [
      alias,
      bank,
      last4,
      network,
      rewardCap,
      rewardCurrency,
      currency,
      pointsFactor,
      baseRate,
    ]) {
      c.dispose();
    }
    for (final r in rules) {
      r.dispose();
    }
    super.onClose();
  }
}
