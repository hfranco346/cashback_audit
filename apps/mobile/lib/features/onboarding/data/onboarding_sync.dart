import 'package:decimal/decimal.dart';

import '../../cards/domain/card_entities.dart';
import '../../cards/domain/card_repository.dart';
import '../../cards/domain/card_validator.dart';
import '../../categories/domain/catalog_repositories.dart';
import '../domain/onboarding_draft.dart';

/// Pushes the draft to the backend right after sign-in, with the existing
/// category and card repositories. Safe to retry: categories are reused by
/// name and the created card id is stored in the draft, so a second attempt
/// never duplicates the card.
class OnboardingSync {
  OnboardingSync({
    required this._cards,
    required this._categories,
    required this._drafts,
  });

  final CardRepository _cards;
  final CategoryRepository _categories;
  final OnboardingDraftRepository _drafts;

  /// Currency used when the user asked to detect it (matches the card form).
  static const fallbackCurrency = 'MXN';

  /// Returns the draft with its `cardId` set. Throws what the repositories
  /// throw (the draft is kept so the caller can retry).
  Future<OnboardingDraft> sync(OnboardingDraft draft) async {
    if (draft.isSynced) return draft;
    final existing = (await _categories.getCategories()).data;
    final ids = {for (final c in existing) c.name.trim().toLowerCase(): c.id};
    final rules = <RewardRule>[];
    for (final item in draft.categories) {
      final key = item.name.trim().toLowerCase();
      var id = ids[key];
      if (id == null) {
        id = (await _categories.createCategory(name: item.name.trim())).id;
        ids[key] = id;
      }
      final rate = CardValidator.parse(item.rate);
      if (rate != null) {
        rules.add(RewardRule(categoryId: id, ratePercent: rate));
      }
    }
    final isPoints = draft.rewardUnit == RewardUnit.points;
    final card = await _cards.createCard(
      CardDraft(
        alias: draft.alias.trim().isEmpty ? draft.bank : draft.alias.trim(),
        bank: draft.bank.trim(),
        last4: draft.last4.trim(),
        rewardUnit: draft.rewardUnit,
        pointsPerCurrencyUnit: isPoints ? Decimal.one : null,
        baseRatePercent: CardValidator.parse(draft.baseRate) ?? Decimal.zero,
        currency: draft.currency ?? fallbackCurrency,
        rules: rules,
      ),
    );
    final synced = draft.copyWith(cardId: card.id);
    await _drafts.save(synced);
    return synced;
  }
}
