import '../../../core/utils/cached.dart';
import 'card_entities.dart';

abstract class CardRepository {
  /// Network-first; serves the local cache when offline.
  Future<Cached<List<CreditCard>>> getCards();
  Future<CreditCard> createCard(CardDraft draft);
  Future<CreditCard> updateCard(String id, CardDraft draft);
  Future<void> deleteCard(String id);
}

/// Saves only the claim email of a card (`PATCH /cards/:id`, `null` clears
/// it). Kept apart from [CardRepository] because it is a partial update.
abstract class ClaimEmailRepository {
  Future<CreditCard> setClaimEmail(String id, String? email);
}
