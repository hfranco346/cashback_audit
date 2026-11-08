import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/utils/decimal_utils.dart';
import '../../categories/presentation/catalog_controller.dart';
import '../domain/card_entities.dart';
import '../domain/card_repository.dart';
import '../domain/card_validator.dart';
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
  });

  final CardRepository _repository;
  final CardsController _cards;
  final CatalogController _catalog;

  /// Null when creating.
  final CreditCard? editing;

  bool get isEditing => editing != null;

  final formKey = GlobalKey<FormState>();
  final alias = TextEditingController();
  final bank = TextEditingController();
  final last4 = TextEditingController();
  final network = TextEditingController();
  final rewardProgram = TextEditingController();
  final currency = TextEditingController(text: 'MXN');
  final pointsFactor = TextEditingController(text: '1');
  final baseRate = TextEditingController();

  final rewardUnit = RewardUnit.cashbackCurrency.obs;
  final rules = <RuleDraft>[].obs;
  final submitting = false.obs;
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
      rewardProgram.text = c.rewardProgramName ?? '';
      currency.text = c.currency;
      pointsFactor.text = decimalToApi(c.pointsPerCurrencyUnit);
      baseRate.text = decimalToApi(c.baseRatePercent);
      rewardUnit.value = c.rewardUnit;
      rules.assignAll([
        for (final r in c.rules)
          RuleDraft(
            categoryId: r.categoryId,
            rate: decimalToApi(r.ratePercent),
            cap: r.monthlyCap == null ? '' : decimalToApi(r.monthlyCap!),
          ),
      ]);
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (!_catalog.loaded.value) _catalog.load();
  }

  void setUnit(RewardUnit unit) => rewardUnit.value = unit;

  /// Category ids not yet used by another rule row.
  bool addRule() {
    if (_catalog.categories.isEmpty) return false;
    final used = rules.map((r) => r.categoryId).toSet();
    final free = _catalog.categories.firstWhereOrNull(
      (c) => !used.contains(c.id),
    );
    if (free == null) return false;
    rules.add(RuleDraft(categoryId: free.id));
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

  /// Validates rule rows; returns true when all are valid.
  bool _validateRules() {
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
    ruleErrors.assignAll(errors);
    return errors.isEmpty;
  }

  CardDraft? buildDraft() {
    final formOk = formKey.currentState?.validate() ?? false;
    final rulesOk = _validateRules();
    if (!formOk || !rulesOk) return null;
    final isPoints = rewardUnit.value == RewardUnit.points;
    return CardDraft(
      alias: alias.text,
      bank: bank.text,
      last4: last4.text,
      network: network.text.trim().isEmpty ? null : network.text,
      rewardProgramName: rewardProgram.text.trim().isEmpty
          ? null
          : rewardProgram.text.trim(),
      rewardUnit: rewardUnit.value,
      pointsPerCurrencyUnit: isPoints
          ? CardValidator.parse(pointsFactor.text)
          : null,
      baseRatePercent: CardValidator.parse(baseRate.text)!,
      currency: currency.text,
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

  @override
  void onClose() {
    for (final c in [
      alias,
      bank,
      last4,
      network,
      rewardProgram,
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
