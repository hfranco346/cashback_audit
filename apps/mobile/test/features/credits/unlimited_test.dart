import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/auth/domain/auth_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/credits/domain/credit_entities.dart';
import 'package:cashback_audit/features/credits/presentation/credits_controller.dart';
import 'package:cashback_audit/features/home/presentation/home_controller.dart';
import 'package:cashback_audit/features/home/presentation/widgets/home_view.dart';
import 'package:cashback_audit/features/settings/presentation/widgets/profile_credits_card.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/presentation/upload_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/upload_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fake_credits_repository.dart';
import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';

import 'package:cashback_audit/features/cards/data/card_mapper.dart';

class _Picker implements PdfPicker {
  @override
  Future<PickedPdf?> pick() async =>
      const PickedPdf(name: 'edo.pdf', path: '/x', sizeBytes: 100);
}

class _Cards implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async => Cached([]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });

  group('model', () {
    test('unlimited accounts always have credits', () {
      final b = CreditBalance.fromJson({
        'free': 0,
        'plan': 0,
        'purchased': 0,
        'total': 0,
        'subscriptionActive': false,
        'unlimited': true,
      });
      expect(b.unlimited, isTrue);
      expect(b.total, 0);
      expect(b.hasCredits, isTrue);
    });

    test('a missing flag means limited', () {
      final b = CreditBalance.fromJson({'free': 0, 'plan': 0, 'purchased': 0});
      expect(b.unlimited, isFalse);
      expect(b.hasCredits, isFalse);
      expect(CreditBalance.fromJson({'free': 1}).hasCredits, isTrue);
    });

    test('the user carries unlimitedCredits (absent = false)', () {
      expect(AppUser.fromJson({'id': 'u'}).unlimitedCredits, isFalse);
      final u = AppUser.fromJson({'id': 'u', 'unlimitedCredits': true});
      expect(u.unlimitedCredits, isTrue);
      expect(AppUser.fromJson(u.toJson()).unlimitedCredits, isTrue);
    });

    test(
      'going unlimited counts as a balance change after a purchase',
      () async {
        final c = CreditsController(
          repository: FakeCreditsRepository([
            balance(),
            balance(unlimited: true),
          ]),
          pollDelays: const [Duration.zero],
          wait: (_) async {},
        );
        c.balance.value = balance();
        expect(c.isUnlimited, isFalse);
        expect(await c.waitForChange(balance()), isTrue);
        expect(c.isUnlimited, isTrue);
      },
    );
  });

  group('gate', () {
    test('an unlimited balance never sends the user to the paywall', () async {
      final nav = FakeNavigator();
      final credits = CreditsController(
        repository: FakeCreditsRepository([balance(unlimited: true)]),
      )..balance.value = balance(unlimited: true);
      final repo = FakeVerificationRepository();
      final c = UploadController(
        repository: repo,
        picker: _Picker(),
        cards: CardsController(_Cards()),
        credits: credits,
        navigator: nav,
        initialCardId: 'c1',
      )..onInit();
      await c.pickFile();
      await c.submit();
      expect(nav.pushed, isEmpty);
      expect(nav.replaced, ['/verification-progress']);
      c.onClose();
    });
  });

  group('screens', () {
    for (final lang in ['es', 'en']) {
      final word = lang == 'es' ? 'Ilimitados' : 'Unlimited';

      testWidgets('profile shows ∞ $word and no purchase button ($lang)', (
        tester,
      ) async {
        await pumpUi(
          tester,
          ProfileCreditsCard(
            balance: balance(unlimited: true),
            onGetMore: () {},
          ),
          lang: lang,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('profile-credits-total')))
              .data,
          '∞ $word',
        );
        expect(find.byKey(const Key('profile-get-more')), findsNothing);
        expect(find.byKey(const Key('bag-free')), findsNothing);
        expect(find.byKey(const Key('profile-unlimited-note')), findsOneWidget);
      });

      testWidgets('verify availability pill says $word ($lang)', (
        tester,
      ) async {
        await pumpUi(
          tester,
          UploadView(
            cards: [CardMapper.fromJson(cardJson())],
            selectedCardId: 'c1',
            onSelectCard: (_) {},
            file: null,
            onPick: () {},
            phase: UploadPhase.idle,
            progress: 0,
            canSubmit: false,
            onSubmit: () {},
            onAddCard: () {},
            onClose: () {},
            balance: balance(unlimited: true),
          ),
          lang: lang,
        );
        expect(find.text('∞ $word'), findsOneWidget);
        expect(find.byKey(const Key('upload-no-credits')), findsNothing);
      });

      testWidgets(
        'home shows the unlimited pill instead of the count ($lang)',
        (tester) async {
          await pumpUi(
            tester,
            HomeView(
              layout: HomeLayout.empty,
              greeting: 'Hola',
              initials: 'AM',
              cards: const [],
              latest: const [],
              pending: const [],
              cardLabel: (_) => '',
              categoryName: (_) => '',
              unlimited: true,
              freeChecks: null,
              onRefresh: () async {},
              onProfile: () {},
              onVerify: () {},
              onAddCard: () {},
              onOpenCard: (_) {},
              onOpenVerification: (_) {},
              onOpenPending: (_) {},
              onSeeAll: () {},
              onGetMore: () {},
              onGuidedSetup: () {},
            ),
            lang: lang,
          );
          expect(find.byKey(const Key('home-unlimited')), findsOneWidget);
          expect(
            find.text(
              lang == 'es'
                  ? '∞ Verificaciones ilimitadas'
                  : '∞ Unlimited checks',
            ),
            findsOneWidget,
          );
        },
      );
    }
  });
}
