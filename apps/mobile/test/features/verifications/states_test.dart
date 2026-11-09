import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';

class _NoCards implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async => const Cached([]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

void main() {
  tearDown(Get.reset);

  testWidgets('confirmation screen: load error shows the message and retries', (
    tester,
  ) async {
    final repo = FakeVerificationRepository()
      ..detailError = const AppException(
        kind: AppErrorKind.notFound,
        statusCode: 404,
        code: 'VERIFICATION_NOT_FOUND',
      )
      ..detailJson = awaitingVerificationJson(id: 'old');
    final controller = ConfirmRatesController(
      repository: repo,
      cards: CardsController(_NoCards()),
      navigator: FakeNavigator(),
      args: const ConfirmRatesArgs.byId('old'),
    );
    Get.put(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ConfirmRatesPage(),
      ),
    );
    await tester.pump();
    // The abandoned statement was cleaned up after 7 days.
    expect(find.text(S.errVerificationNotFound), findsOneWidget);

    repo.detailError = null;
    await tester.tap(find.text(S.retry));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('rate-field-base')), findsOneWidget);
  });
}
