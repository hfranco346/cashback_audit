import 'package:cashback_audit/core/ui/ui.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/credits/domain/credit_entities.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/upload_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_progress_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/verification_progress_page.dart';
import 'package:cashback_audit/features/verifications/presentation/widgets/upload_view.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/ui/ui_harness.dart';
import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';

CreditBalance _balance({int free = 0, int plan = 0, int purchased = 0}) =>
    CreditBalance(
      free: free,
      plan: plan,
      purchased: purchased,
      total: free + plan + purchased,
      subscriptionActive: false,
    );

final _cards = [
  CardMapper.fromJson(cardJson()),
  CardMapper.fromJson(cardJson(id: 'c2', alias: 'Travel')),
];

UploadView _upload({
  UploadPhase phase = UploadPhase.idle,
  PickedPdf? file,
  bool canSubmit = false,
  String? selected = 'c1',
  VoidCallback? onSubmit,
  ValueChanged<String>? onSelect,
  VoidCallback? onClose,
  CreditBalance? balance,
  VoidCallback? onSeePlans,
  String? error,
}) => UploadView(
  cards: _cards,
  selectedCardId: selected,
  onSelectCard: onSelect ?? (_) {},
  file: file,
  onPick: () {},
  phase: phase,
  progress: 0.4,
  canSubmit: canSubmit,
  onSubmit: onSubmit ?? () {},
  onAddCard: () {},
  onClose: onClose ?? () {},
  balance: balance,
  onSeePlans: onSeePlans,
  errorMessage: error,
);

const _pdf = PickedPdf(name: 'edo.pdf', path: '/x', sizeBytes: 2048);

void main() {
  group('UploadView', () {
    testWidgets('idle: submit says what is missing and stays disabled', (
      tester,
    ) async {
      await pumpUi(tester, _upload());
      final l10n = AppLocalizations.of(tester.element(find.byType(UploadView)));
      expect(find.text(l10n.verifyStepCard.toUpperCase()), findsOneWidget);
      expect(find.text(l10n.verifyStepFile.toUpperCase()), findsOneWidget);
      expect(find.text('Daily •••• 4321'), findsOneWidget);
      expect(find.text(l10n.verifyPickHint), findsOneWidget);
      expect(find.text(l10n.verifyCtaPickFile), findsOneWidget);
      final btn = tester.widget<AppButton>(
        find.byKey(const Key('verify-button')),
      );
      expect(btn.onPressed, isNull);

      await pumpUi(tester, _upload(selected: null));
      expect(find.text(l10n.verifyCtaPickCard), findsOneWidget);
    });

    testWidgets('card subtitle names the reward and the rules', (tester) async {
      await pumpUi(tester, _upload());
      expect(find.textContaining('Cashback en MXN'), findsWidgets);
      await pumpUi(tester, _upload(), lang: 'en');
      expect(find.textContaining('Cashback in MXN'), findsWidgets);
    });

    testWidgets('file picked: shows it, selects a card and submits', (
      tester,
    ) async {
      var submitted = 0;
      var closed = 0;
      String? selected;
      await pumpUi(
        tester,
        _upload(
          file: _pdf,
          canSubmit: true,
          onSubmit: () => submitted++,
          onSelect: (id) => selected = id,
          onClose: () => closed++,
        ),
      );
      expect(find.text('edo.pdf'), findsOneWidget);
      await tester.tap(find.byKey(const Key('card-chip-c2')));
      expect(selected, 'c2');
      await tester.tap(find.byKey(const Key('verify-button')));
      expect(submitted, 1);
      await tester.tap(find.byKey(const Key('verify-close')));
      expect(closed, 1);
    });

    testWidgets('uploading shows real progress and the file', (tester) async {
      await pumpUi(tester, _upload(phase: UploadPhase.uploading, file: _pdf));
      final l10n = AppLocalizations.of(tester.element(find.byType(UploadView)));
      expect(find.text(l10n.uploading), findsOneWidget);
      expect(find.byKey(const Key('processing-file')), findsOneWidget);
      expect(find.text('edo.pdf'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('processing-track')),
      );
      expect(bar.value, 0.4);
      // Says the app can be closed.
      expect(find.text(l10n.processingCanLeave), findsOneWidget);
    });

    testWidgets('analyzing keeps the reading checklist', (tester) async {
      await pumpUi(tester, _upload(phase: UploadPhase.analyzing, file: _pdf));
      final l10n = AppLocalizations.of(tester.element(find.byType(UploadView)));
      expect(find.text(l10n.processingAnalyzing), findsOneWidget);
      expect(find.text(l10n.processingStepClassify), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('credit note: available pill, none left, unknown', (
      tester,
    ) async {
      await pumpUi(tester, _upload(balance: _balance(plan: 5)));
      final l10n = AppLocalizations.of(tester.element(find.byType(UploadView)));
      expect(find.text(l10n.verifyAvailablePill(5)), findsOneWidget);
      expect(find.text(l10n.verifyCreditNote), findsOneWidget);

      var plans = 0;
      await pumpUi(
        tester,
        _upload(balance: _balance(), onSeePlans: () => plans++),
      );
      expect(find.text(l10n.uploadNoCredits), findsOneWidget);
      await tester.tap(find.text(l10n.seePlans));
      expect(plans, 1);

      await pumpUi(tester, _upload());
      expect(find.byKey(const Key('upload-credit-note')), findsNothing);
    });

    testWidgets('shows an upload error inline with an icon', (tester) async {
      await pumpUi(tester, _upload(error: 'Choose a PDF file.'));
      expect(find.text('Choose a PDF file.'), findsOneWidget);
      expect(find.byIcon(Icons.priority_high_rounded), findsOneWidget);
    });

    testWidgets('no cards offers to add one', (tester) async {
      await pumpUi(
        tester,
        UploadView(
          cards: const [],
          selectedCardId: null,
          onSelectCard: (_) {},
          file: null,
          onPick: () {},
          phase: UploadPhase.idle,
          progress: 0,
          canSubmit: false,
          onSubmit: () {},
          onAddCard: () {},
          onClose: () {},
        ),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(UploadView)));
      expect(find.text(l10n.noCardsForUpload), findsOneWidget);
      expect(find.byKey(const Key('verify-add-card')), findsOneWidget);
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('renders without overflow (dark=$dark, $lang)', (
          tester,
        ) async {
          await pumpUi(
            tester,
            _upload(file: _pdf, canSubmit: true, balance: _balance(free: 1)),
            dark: dark,
            lang: lang,
          );
          expect(tester.takeException(), isNull);
          await pumpUi(
            tester,
            _upload(phase: UploadPhase.uploading, file: _pdf),
            dark: dark,
            lang: lang,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('FailedAnalysis', () {
    for (final lang in ['es', 'en']) {
      for (final code in FailureCode.values) {
        testWidgets('${code.name} ($lang): reason, refund and retry', (
          tester,
        ) async {
          var retried = 0;
          var done = 0;
          await pumpUi(
            tester,
            FailedAnalysis(
              code: code,
              onRetry: () => retried++,
              onDone: () => done++,
            ),
            lang: lang,
          );
          await tester.pump(const Duration(seconds: 1));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(FailedAnalysis)),
          );
          expect(find.byKey(const Key('failure-title')), findsOneWidget);
          expect(find.text(l10n.failureRefundedPill), findsOneWidget);
          expect(
            find.text(
              code == FailureCode.notAStatement
                  ? l10n.failureChooseAnother
                  : l10n.failureRetry,
            ),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const Key('failure-retry')));
          await tester.tap(find.byKey(const Key('failure-home')));
          expect([retried, done], [1, 1]);
        });
      }
    }

    testWidgets('dark theme smoke', (tester) async {
      await pumpUi(
        tester,
        FailedAnalysis(code: null, onRetry: () {}, onDone: () {}),
        dark: true,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('VerificationProgressController', () {
    test(
      'retry marks the failure seen and reopens verify on the card',
      () async {
        final repo = FakeVerificationRepository()
          ..getResults.add({
            ...verificationJson(),
            'status': 'FAILED',
            'failureCode': 'NOT_A_STATEMENT',
          });
        final nav = FakeNavigator();
        final c = VerificationProgressController(
          verificationId: 'v1',
          repository: repo,
          navigator: nav,
        )..onReady();
        await Future<void>.delayed(Duration.zero);
        expect(c.verification.value?.isFailed, isTrue);
        await c.retryUpload();
        expect(nav.replaced, ['/upload']);
        expect(nav.replacedArgs.single, c.verification.value?.cardId);
        c.onClose();
      },
    );

    test('args accept a bare id or the full object', () {
      expect(VerificationProgressArgs.from('v9').verificationId, 'v9');
      final a = VerificationProgressArgs.from(
        const VerificationProgressArgs('v2', fileName: 'a.pdf'),
      );
      expect((a.verificationId, a.fileName), ('v2', 'a.pdf'));
      expect(() => VerificationProgressArgs.from(3), throwsArgumentError);
    });
  });
}
