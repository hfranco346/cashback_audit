import 'package:equatable/equatable.dart';

import '../../cards/domain/card_entities.dart';

/// Where the guided setup is. The order is the order of the screens.
enum OnboardingStep { demo, bank, card, categories, account, pdf, verdict }

/// A category the user ticked, with its percentage as typed (empty = "I do
/// not know": the statement will tell).
class DraftCategory extends Equatable {
  const DraftCategory({required this.name, this.rate = ''});

  final String name;
  final String rate;

  DraftCategory withRate(String value) =>
      DraftCategory(name: name, rate: value);

  Map<String, dynamic> toJson() => {'name': name, 'rate': rate};

  factory DraftCategory.fromJson(Map<String, dynamic> j) => DraftCategory(
    name: (j['name'] as String?) ?? '',
    rate: (j['rate'] as String?) ?? '',
  );

  @override
  List<Object?> get props => [name, rate];
}

/// Everything the guided setup captured before (or after) sign-in. It lives
/// on the device until it has been pushed to the backend.
class OnboardingDraft extends Equatable {
  const OnboardingDraft({
    this.step = OnboardingStep.demo,
    this.bank = '',
    this.alias = '',
    this.last4 = '',
    this.rewardUnit = RewardUnit.cashbackCurrency,
    this.currency,
    this.categories = const [],
    this.baseRate = '0',
    this.cardId,
    this.categoriesSeeded = false,
  });

  final OnboardingStep step;
  final String bank;
  final String alias;
  final String last4;
  final RewardUnit rewardUnit;

  /// ISO code of the card/reward currency; null = "detect it for me".
  final String? currency;
  final List<DraftCategory> categories;

  /// Rate for everything outside the categories, as typed.
  final String baseRate;

  /// Set once the card exists in the backend (makes the sync idempotent).
  final String? cardId;

  /// The common categories were offered already (prefilled once), so going
  /// back to the step never restores what the user cleared.
  final bool categoriesSeeded;

  bool get isSynced => cardId != null;

  OnboardingDraft copyWith({
    OnboardingStep? step,
    String? bank,
    String? alias,
    String? last4,
    RewardUnit? rewardUnit,
    String? Function()? currency,
    List<DraftCategory>? categories,
    String? baseRate,
    String? cardId,
    bool? categoriesSeeded,
  }) => OnboardingDraft(
    step: step ?? this.step,
    bank: bank ?? this.bank,
    alias: alias ?? this.alias,
    last4: last4 ?? this.last4,
    rewardUnit: rewardUnit ?? this.rewardUnit,
    currency: currency != null ? currency() : this.currency,
    categories: categories ?? this.categories,
    baseRate: baseRate ?? this.baseRate,
    cardId: cardId ?? this.cardId,
    categoriesSeeded: categoriesSeeded ?? this.categoriesSeeded,
  );

  Map<String, dynamic> toJson() => {
    'step': step.name,
    'bank': bank,
    'alias': alias,
    'last4': last4,
    'rewardUnit': rewardUnit.apiValue,
    'currency': currency,
    'categories': [for (final c in categories) c.toJson()],
    'baseRate': baseRate,
    'cardId': cardId,
    'categoriesSeeded': categoriesSeeded,
  };

  factory OnboardingDraft.fromJson(Map<String, dynamic> j) => OnboardingDraft(
    step: OnboardingStep.values.firstWhere(
      (s) => s.name == j['step'],
      orElse: () => OnboardingStep.demo,
    ),
    bank: (j['bank'] as String?) ?? '',
    alias: (j['alias'] as String?) ?? '',
    last4: (j['last4'] as String?) ?? '',
    rewardUnit: RewardUnit.fromApi(
      (j['rewardUnit'] as String?) ?? 'CASHBACK_CURRENCY',
    ),
    currency: j['currency'] as String?,
    categories: [
      if (j['categories'] is List)
        for (final c in j['categories'] as List)
          if (c is Map) DraftCategory.fromJson(Map<String, dynamic>.from(c)),
    ],
    baseRate: (j['baseRate'] as String?) ?? '0',
    cardId: j['cardId'] as String?,
    categoriesSeeded: (j['categoriesSeeded'] as bool?) ?? false,
  );

  @override
  List<Object?> get props => [
    step,
    bank,
    alias,
    last4,
    rewardUnit,
    currency,
    categories,
    baseRate,
    cardId,
    categoriesSeeded,
  ];
}

/// Local storage of the draft and of the "just finished the setup" flag that
/// makes Home show exactly what was registered.
abstract class OnboardingDraftRepository {
  Future<OnboardingDraft?> read();
  Future<void> save(OnboardingDraft draft);
  Future<void> clear();

  Future<bool> isJustOnboarded();
  Future<void> setJustOnboarded(bool value);
}
