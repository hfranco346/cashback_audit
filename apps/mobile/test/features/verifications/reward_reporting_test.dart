import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/core/ui/ui.dart';
import 'package:cashback_audit/core/utils/cached.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/categories/presentation/catalog_controller.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/features/verifications/domain/pdf_picker.dart';
import 'package:cashback_audit/features/verifications/domain/verification_entities.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/confirm_rates_page.dart';
import 'package:cashback_audit/features/verifications/presentation/result_controller.dart';
import 'package:cashback_audit/features/verifications/presentation/result_page.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_verification_repository.dart';
import '../../support/fakes.dart';
import '../../support/fixtures.dart';
import '../categories/fake_catalog.dart';

class _CardRepo implements CardRepository {
  @override
  Future<Cached<List<CreditCard>>> getCards() async =>
      Cached([CardMapper.fromJson(cardJson())]);
  @override
  Future<CreditCard> createCard(CardDraft draft) => throw UnimplementedError();
  @override
  Future<CreditCard> updateCard(String id, CardDraft draft) =>
      throw UnimplementedError();
  @override
  Future<void> deleteCard(String id) async {}
}

class _Picker implements PdfPicker {
  PickedPdf? next = const PickedPdf(
    name: 'setiembre.pdf',
    path: '/tmp/setiembre.pdf',
    sizeBytes: 2000,
  );
  @override
  Future<PickedPdf?> pick() async => next;
}

Decimal _d(String s) => Decimal.parse(s);

/// A statement whose program prints the accumulated balance.
Map<String, dynamic> _awaiting({
  Map<String, dynamic>? proposal,
  bool withProposal = true,
}) =>
    awaitingVerificationJson(
      rateProposal: [proposalJson(null, null, '1', 'CARD_RULE')],
      selectedProgram: programJson('CASH BAC', '4500'),
      programs: [programJson('CASH BAC', '4500')],
    )..addAll({
      'rewardCurrency': 'HNL',
      if (withProposal)
        'rewardReportingProposal': {
          'mode': 'MONTHLY',
          'suggestedMode': 'MONTHLY',
          'reason': 'NONE',
          'cardSetting': 'AUTO',
          'currentBalance': '4500',
          'previousBalance': null,
          'previousBalanceSource': null,
          'previousVerificationId': null,
          'redeemedInPeriod': '200',
          'expiredInPeriod': '50',
          'earned': null,
          'previousBalanceRequired': false,
          'programName': 'CASH BAC',
          'reportedLabel': 'Acumulado',
          ...?proposal,
        },
    });

Map<String, dynamic> _cumulativeProposal({
  String reason = 'LABEL_SAYS_ACCUMULATED',
  String? previous,
  String? source,
}) => {
  'mode': 'CUMULATIVE',
  'suggestedMode': 'CUMULATIVE',
  'reason': reason,
  'previousBalance': previous,
  'previousBalanceSource': source,
  'previousBalanceRequired': previous == null,
};

Map<String, dynamic> _completedCumulative() =>
    verificationJson(verdict: 'MATCH')
      ..['rewardReporting'] = {
        'mode': 'CUMULATIVE',
        'currentBalance': '4500',
        'previousBalance': '3000',
        'previousBalanceSource': 'PREVIOUS_VERIFICATION',
        'redeemedInPeriod': '200',
        'expiredInPeriod': '50',
        'earned': '1750',
      };

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late FakeVerificationRepository repo;
  late FakeNavigator nav;
  late _Picker picker;
  setUp(() {
    repo = FakeVerificationRepository()..detailJson = ficohsaCompletedJson();
    nav = FakeNavigator();
    picker = _Picker();
  });

  ConfirmRatesController make(Map<String, dynamic> json) {
    final c = ConfirmRatesController(
      repository: repo,
      cards: CardsController(_CardRepo()),
      navigator: nav,
      picker: picker,
      args: ConfirmRatesArgs.verification(VerificationMapper.detail(json)),
    )..onInit();
    addTearDown(c.onClose);
    return c;
  }

  group('mapper', () {
    test('parses the proposal and tolerates its absence', () {
      final v = VerificationMapper.detail(
        _awaiting(
          proposal: _cumulativeProposal(previous: '3000', source: 'STATEMENT'),
        ),
      );
      final p = v.rewardReportingProposal!;
      expect(p.mode, RewardReporting.cumulative);
      expect(p.reason, ReportingReason.labelSaysAccumulated);
      expect(p.previousBalance, _d('3000'));
      expect(p.previousBalanceSource, PreviousBalanceSource.statement);
      expect(p.redeemedInPeriod, _d('200'));
      expect(p.reportedLabel, 'Acumulado');
      final old = VerificationMapper.detail(_awaiting(withProposal: false));
      expect(old.rewardReportingProposal, isNull);
      expect(old.rewardReporting, isNull);
    });

    test('parses the completed derivation', () {
      final r = VerificationMapper.detail(_completedCumulative())
          .rewardReporting!;
      expect(r.isCumulative, isTrue);
      expect(r.earned, _d('1750'));
      expect(
        r.previousBalanceSource,
        PreviousBalanceSource.previousVerification,
      );
    });

    test('confirm body carries rewardReporting', () {
      final body = VerificationMapper.confirmBody(
        ConfirmRequest(
          baseRatePercent: _d('1'),
          categoryRates: const [],
          rewardReporting: RewardReportingInput(
            mode: RewardReporting.cumulative,
            previousBalance: _d('3000.5'),
            previousBalanceSource: PreviousBalanceSource.previousStatement,
            rememberForCard: true,
          ),
        ),
      );
      expect(body['rewardReporting'], {
        'mode': 'CUMULATIVE',
        'previousBalance': '3000.5',
        'previousBalanceSource': 'PREVIOUS_STATEMENT',
        'rememberForCard': true,
      });
      final none = VerificationMapper.confirmBody(
        ConfirmRequest(baseRatePercent: _d('1'), categoryRates: const []),
      );
      expect(none.containsKey('rewardReporting'), isFalse);
    });

    test('previous statement result', () {
      final r = VerificationMapper.previousStatement({
        'programs': [
          {'name': 'CASH BAC', 'balance': '3000', 'periodEnd': '2025-12-31'},
          {'name': 'broken', 'balance': null},
        ],
        'matchedBalance': null,
      });
      expect(r.programs.single.balance, _d('3000'));
      expect(r.matchedBalance, isNull);
    });
  });

  group('controller: reporting question', () {
    test('no proposal: no section, nothing sent', () async {
      final c = make(_awaiting(withProposal: false));
      expect(c.showReporting, isFalse);
      expect(c.canConfirm, isTrue);
      await c.confirm();
      expect(repo.confirmRequests.single.rewardReporting, isNull);
    });

    test('preselects the proposed mode and explains why', () {
      final c = make(
        _awaiting(
          proposal: _cumulativeProposal(
            reason: 'STATEMENT_HAS_PREVIOUS_BALANCE',
            previous: '3000',
            source: 'STATEMENT',
          ),
        ),
      );
      expect(c.reportingMode.value, RewardReporting.cumulative);
      expect(
        c.reportingProposal.value!.reason,
        ReportingReason.statementHasPreviousBalance,
      );
      expect(c.previousBalance.text, '3000');
      expect(c.previousBalanceSource.value, PreviousBalanceSource.statement);
      expect(c.rememberReporting.value, isFalse);
      expect(c.canConfirm, isTrue);
      expect(c.liveEarned, _d('1750'));
    });

    test('changing the answer turns remember on; going back turns it off', () {
      final c = make(_awaiting());
      expect(c.reportingMode.value, RewardReporting.monthly);
      c.setReportingMode(RewardReporting.cumulative);
      expect(c.rememberReporting.value, isTrue);
      c.setRememberReporting(false);
      expect(c.rememberReporting.value, isFalse);
      c.setReportingMode(RewardReporting.monthly);
      expect(c.rememberReporting.value, isFalse);
    });

    test('monthly sends only the mode and the remember flag', () async {
      final c = make(_awaiting());
      await c.confirm();
      expect(
        repo.confirmRequests.single.rewardReporting,
        const RewardReportingInput(mode: RewardReporting.monthly),
      );
    });

    test('cumulative without a previous balance blocks and says so', () {
      final c = make(_awaiting());
      c.setReportingMode(RewardReporting.cumulative);
      expect(c.previousBalanceRequired, isTrue);
      expect(c.canConfirm, isFalse);
      expect(c.missingFields, contains(S.current.reportingPreviousLabel));
      c.previousBalance.text = 'abc';
      expect(c.previousBalanceError, isNotNull);
      expect(c.invalidFields, contains(S.current.reportingPreviousLabel));
      expect(c.canConfirm, isFalse);
      c.previousBalance.text = '3000,50';
      expect(c.canConfirm, isTrue);
    });

    test('a typed balance is sent as USER with remember', () async {
      final c = make(_awaiting());
      c.setReportingMode(RewardReporting.cumulative);
      c.previousBalance.text = '3000';
      expect(c.previousBalanceSource.value, PreviousBalanceSource.user);
      await c.confirm();
      expect(
        repo.confirmRequests.single.rewardReporting,
        RewardReportingInput(
          mode: RewardReporting.cumulative,
          previousBalance: _d('3000'),
          previousBalanceSource: PreviousBalanceSource.user,
          rememberForCard: true,
        ),
      );
    });

    test('a prefilled balance keeps its source until edited', () async {
      final c = make(
        _awaiting(
          proposal: _cumulativeProposal(
            reason: 'CARD_SETTING',
            previous: '3000',
            source: 'PREVIOUS_VERIFICATION',
          ),
        ),
      );
      expect(
        c.previousBalanceSource.value,
        PreviousBalanceSource.previousVerification,
      );
      await c.confirm();
      expect(
        repo.confirmRequests.single.rewardReporting?.previousBalanceSource,
        PreviousBalanceSource.previousVerification,
      );
      c.previousBalance.text = '3100';
      expect(c.previousBalanceSource.value, PreviousBalanceSource.user);
      c.previousBalance.text = '';
      expect(c.previousBalanceSource.value, isNull);
      expect(c.previousBalanceRequired, isTrue);
    });

    test('live earned follows the rule and a negative one only warns', () {
      final c = make(_awaiting());
      c.setReportingMode(RewardReporting.cumulative);
      expect(c.liveEarned, isNull);
      c.previousBalance.text = '3000';
      expect(c.liveEarned, _d('1750'));
      c.previousBalance.text = '6000';
      expect(c.liveEarned, _d('-1250'));
      expect(c.canConfirm, isTrue);
    });

    test('statement that prints the earned amount needs no balance', () {
      final c = make(
        _awaiting(
          proposal: {
            ..._cumulativeProposal(reason: 'NONE'),
            'earned': '800',
          },
        ),
      );
      expect(c.previousBalanceRequired, isFalse);
      expect(c.canConfirm, isTrue);
      expect(c.liveEarned, _d('800'));
    });

    test('PREVIOUS_BALANCE_REQUIRED turns the field required', () async {
      repo.confirmErrors.add(
        const AppException(
          kind: AppErrorKind.unprocessable,
          statusCode: 422,
          code: 'PREVIOUS_BALANCE_REQUIRED',
        ),
      );
      final c = make(
        _awaiting(proposal: {..._cumulativeProposal(), 'earned': '800'}),
      );
      await c.confirm();
      expect(c.errorMessage.value, S.errPreviousBalanceRequired);
      expect(c.previousBalanceRequired, isTrue);
      expect(c.canConfirm, isFalse);
      c.previousBalance.text = '3000';
      expect(c.canConfirm, isTrue);
    });

    test('PREVIOUS_BALANCE_REQUIRED works without a proposal too', () async {
      repo.confirmErrors.add(
        const AppException(
          kind: AppErrorKind.unprocessable,
          code: 'PREVIOUS_BALANCE_REQUIRED',
        ),
      );
      final c = make(_awaiting(withProposal: false));
      await c.confirm();
      expect(c.showReporting, isTrue);
      expect(c.isCumulative, isTrue);
      expect(c.previousBalanceRequired, isTrue);
    });

    test('a recalculation keeps the cumulative derivation', () async {
      final c = make(_completedCumulative());
      expect(c.reportingMode.value, RewardReporting.cumulative);
      expect(c.previousBalance.text, '3000');
      expect(
        c.previousBalanceSource.value,
        PreviousBalanceSource.previousVerification,
      );
      c.setReportingMode(RewardReporting.monthly);
      await c.confirm();
      expect(
        repo.confirmRequests.single.rewardReporting?.mode,
        RewardReporting.monthly,
      );
    });
  });

  group('controller: previous month PDF', () {
    ConfirmRatesController cumulative() =>
        make(_awaiting(proposal: _cumulativeProposal()));

    test('a matched balance fills the field', () async {
      repo.previousResult = PreviousStatementResult(
        matchedBalance: _d('2950.25'),
        programs: [
          PreviousStatementProgram(name: 'CASH BAC', balance: _d('2950.25')),
        ],
      );
      final c = cumulative();
      expect(c.canConfirm, isFalse);
      await c.pickPreviousStatement();
      expect(repo.previousUploads.single.path, '/tmp/setiembre.pdf');
      expect(repo.previousUploads.single.id, 'v1');
      expect(c.previousBalance.text, '2950.25');
      expect(
        c.previousBalanceSource.value,
        PreviousBalanceSource.previousStatement,
      );
      expect(c.uploadingPrevious.value, isFalse);
      expect(c.previousUploadProgress.value, 1);
      expect(c.canConfirm, isTrue);
      await c.confirm();
      expect(
        repo.confirmRequests.single.rewardReporting?.previousBalanceSource,
        PreviousBalanceSource.previousStatement,
      );
    });

    test('no match: the user picks among the programs read', () async {
      repo.previousResult = PreviousStatementResult(
        programs: [
          PreviousStatementProgram(name: 'A', balance: _d('10')),
          PreviousStatementProgram(name: 'B', balance: _d('20')),
        ],
      );
      final c = cumulative();
      await c.pickPreviousStatement();
      expect(c.previousBalance.text, isEmpty);
      expect(c.previousProgramChoices.map((p) => p.name), ['A', 'B']);
      c.choosePreviousProgram(c.previousProgramChoices.last);
      expect(c.previousBalance.text, '20');
      expect(
        c.previousBalanceSource.value,
        PreviousBalanceSource.previousStatement,
      );
      expect(c.previousProgramChoices, isEmpty);
    });

    test('nothing read at all says the program was not found', () async {
      final c = cumulative();
      await c.pickPreviousStatement();
      expect(c.previousUploadError.value, S.errProgramNotFound);
      expect(c.previousBalance.text, isEmpty);
    });

    test('NOT_A_STATEMENT and PROGRAM_NOT_FOUND show their messages', () async {
      final c = cumulative();
      repo.previousError = const AppException(
        kind: AppErrorKind.unprocessable,
        statusCode: 422,
        code: 'NOT_A_STATEMENT',
      );
      await c.pickPreviousStatement();
      expect(c.previousUploadError.value, S.errNotAStatement);
      repo.previousError = const AppException(
        kind: AppErrorKind.unprocessable,
        statusCode: 422,
        code: 'PROGRAM_NOT_FOUND',
      );
      await c.pickPreviousStatement();
      expect(c.previousUploadError.value, S.errProgramNotFound);
      expect(c.uploadingPrevious.value, isFalse);
      repo.previousError = const AppException(kind: AppErrorKind.timeout);
      await c.pickPreviousStatement();
      expect(c.previousUploadError.value, S.errTimeout);
    });

    test('rejects non-PDF and oversized files; cancel does nothing', () async {
      final c = cumulative();
      picker.next = const PickedPdf(name: 'a.png', path: '/a', sizeBytes: 1);
      await c.pickPreviousStatement();
      expect(c.previousUploadError.value, S.fileNotPdf);
      picker.next = const PickedPdf(
        name: 'a.pdf',
        path: '/a',
        sizeBytes: 11 * 1024 * 1024,
      );
      await c.pickPreviousStatement();
      expect(c.previousUploadError.value, S.fileTooLarge);
      picker.next = null;
      await c.pickPreviousStatement();
      expect(repo.previousUploads, isEmpty);
    });
  });

  group('widgets', () {
    Future<ConfirmRatesController> pumpConfirm(
      WidgetTester tester,
      Map<String, dynamic> json, {
      bool dark = false,
      String lang = 'es',
    }) async {
      tester.view.physicalSize = const Size(390, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ActiveLocale.set(Locale(lang));
      S.current = ActiveLocale.strings;
      final c = make(json);
      Get.put<ConfirmRatesController>(c);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ConfirmRatesPage(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      return c;
    }

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        final tag = '${dark ? 'dark' : 'light'} $lang';

        testWidgets('confirm section ($tag)', (tester) async {
          final c = await pumpConfirm(
            tester,
            _awaiting(proposal: _cumulativeProposal()),
            dark: dark,
            lang: lang,
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(ConfirmRatesPage)),
          );
          expect(find.text(l10n.reportingTitle), findsOneWidget);
          expect(find.text('CASH BAC'), findsWidgets);
          expect(find.byKey(const Key('reporting-figure')), findsOneWidget);
          expect(find.text(l10n.evidenceQuote('Acumulado')), findsOneWidget);
          expect(find.text(l10n.reportingQuestion), findsOneWidget);
          expect(find.text(l10n.reportingModeMonthly), findsOneWidget);
          expect(find.text(l10n.reportingModeCumulative), findsOneWidget);
          expect(
            find.text(l10n.reportingReasonLabel('Acumulado')),
            findsOneWidget,
          );
          expect(find.text(l10n.reportingRemember), findsOneWidget);
          // Required previous balance, with the free upload offer.
          expect(find.byKey(const Key('previous-required')), findsOneWidget);
          expect(find.text(l10n.reportingUploadCta), findsOneWidget);
          expect(find.text(l10n.reportingUploadNote), findsOneWidget);
          expect(
            find.text(l10n.confirmMissingOne(l10n.reportingPreviousLabel)),
            findsOneWidget,
          );
          expect(
            tester
                .widget<AppButton>(find.byKey(const Key('confirm-button')))
                .onPressed,
            isNull,
          );

          // Typing the balance shows the derivation.
          await tester.enterText(
            find.byKey(const Key('previous-balance-field')),
            '3000',
          );
          await tester.pump();
          expect(find.byKey(const Key('derivation-earned')), findsOneWidget);
          expect(find.text(l10n.reportingPrevSourceUser), findsOneWidget);
          expect(find.byKey(const Key('previous-required')), findsNothing);
          expect(find.byKey(const Key('reporting-negative')), findsNothing);
          expect(c.liveEarned, _d('1750'));

          // A balance above the current one only warns.
          await tester.enterText(
            find.byKey(const Key('previous-balance-field')),
            '9000',
          );
          await tester.pump();
          expect(find.byKey(const Key('reporting-negative')), findsOneWidget);

          // Back to "earned this month": the balance block goes away.
          await tester.tap(find.text(l10n.reportingModeMonthly));
          await tester.pump();
          expect(find.byKey(const Key('previous-balance-field')), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('prefilled source labels (es)', (tester) async {
      await pumpConfirm(
        tester,
        _awaiting(
          proposal: {
            ..._cumulativeProposal(
              reason: 'CARD_SETTING',
              previous: '3000',
              source: 'PREVIOUS_VERIFICATION',
            ),
            'previousPeriodEnd': '2025-12-31',
          },
        ),
      );
      expect(find.text('De tu verificación de Diciembre'), findsOneWidget);
      expect(find.text('Así lo marcaste para esta tarjeta'), findsOneWidget);
      expect(find.byKey(const Key('upload-previous')), findsOneWidget);
    });

    testWidgets('uploading the PDF fills the field (en)', (tester) async {
      repo.previousResult = PreviousStatementResult(matchedBalance: _d('2950'));
      await pumpConfirm(
        tester,
        _awaiting(proposal: _cumulativeProposal()),
        lang: 'en',
      );
      await tester.tap(find.byKey(const Key('upload-previous')));
      await tester.pump();
      await tester.pump();
      expect(find.text("From last month's PDF"), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('previous-balance-field')))
            .controller!
            .text,
        '2950',
      );
    });

    for (final dark in [false, true]) {
      for (final lang in ['es', 'en']) {
        testWidgets('result derivation (${dark ? 'dark' : 'light'} $lang)', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 2600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          ActiveLocale.set(Locale(lang));
          S.current = ActiveLocale.strings;
          final json = _completedCumulative();
          repo.detailJson = json;
          final catalog = CatalogController(
            categories: FakeCategoryRepository(const []),
            merchants: FakeMerchantRepository(),
          );
          final c = ResultController(
            repository: repo,
            catalog: catalog,
            navigator: nav,
            initial: VerificationMapper.detail(json),
          )..onInit();
          Get.put<ResultController>(c);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              locale: Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const ResultPage(),
            ),
          );
          await tester.pump(const Duration(seconds: 2));
          final l10n = AppLocalizations.of(
            tester.element(find.byType(ResultPage)),
          );
          expect(find.text(l10n.reportingCurrentBalance), findsOneWidget);
          expect(
            find.textContaining(l10n.reportingPreviousBalance),
            findsWidgets,
          );
          expect(find.byKey(const Key('derivation-earned')), findsOneWidget);
          expect(find.textContaining(l10n.reportedDerivedNote), findsOneWidget);
          expect(
            find.text(
              '${l10n.reportingPreviousLabel}: ${l10n.reportingPrevSourceVerification}',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('a monthly result shows no derivation', (tester) async {
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final json = verificationJson();
      repo.detailJson = json;
      final c = ResultController(
        repository: repo,
        catalog: CatalogController(
          categories: FakeCategoryRepository(const []),
          merchants: FakeMerchantRepository(),
        ),
        navigator: nav,
        initial: VerificationMapper.detail(json),
      )..onInit();
      Get.put<ResultController>(c);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const ResultPage(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('reward-derivation-section')), findsNothing);
    });
  });
}
