import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_messages.dart';
import '../domain/card_entities.dart';
import '../domain/card_repository.dart';

class CardsController extends GetxController {
  CardsController(this._repository);

  final CardRepository _repository;

  final cards = <CreditCard>[].obs;
  final loading = false.obs;
  final errorMessage = RxnString();

  /// True when the visible list comes from the offline cache.
  final offline = false.obs;

  /// True once a first load finished (success or not).
  final loaded = false.obs;

  CreditCard? byId(String id) => cards.firstWhereOrNull((c) => c.id == id);

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.getCards();
      cards.assignAll(result.data);
      offline.value = result.fromCache;
    } catch (e) {
      errorMessage.value = userMessageFor(e);
    } finally {
      loading.value = false;
      loaded.value = true;
    }
  }

  /// Swaps in a card the backend just returned (e.g. after a partial PATCH).
  void replace(CreditCard card) {
    final i = cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) cards[i] = card;
  }

  /// Returns an error message, or `null` on success.
  Future<String?> delete(CreditCard card) async {
    try {
      await _repository.deleteCard(card.id);
      cards.removeWhere((c) => c.id == card.id);
      return null;
    } on AppException catch (e) {
      return userMessageFor(e);
    }
  }
}
