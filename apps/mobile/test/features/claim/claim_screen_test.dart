import 'package:cashback_audit/core/errors/app_exception.dart';
import 'package:cashback_audit/core/l10n/active_locale.dart';
import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/routing/app_navigator.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/cards/data/card_mapper.dart';
import 'package:cashback_audit/features/cards/domain/card_entities.dart';
import 'package:cashback_audit/features/cards/domain/card_repository.dart';
import 'package:cashback_audit/features/cards/presentation/cards_controller.dart';
import 'package:cashback_audit/features/claim/domain/claim_email.dart';
import 'package:cashback_audit/features/claim/domain/mail_launcher.dart';
import 'package:cashback_audit/features/claim/presentation/claim_controller.dart';
import 'package:cashback_audit/features/claim/presentation/claim_page.dart';
import 'package:cashback_audit/features/verifications/data/verification_mapper.dart';
import 'package:cashback_audit/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fakes.dart';
import '../../support/fixtures.dart';

class _Launcher implements MailLauncher {
  _Launcher({this.result = true});
  final bool result;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

class _ClaimRepo implements ClaimEmailRepository {
  _ClaimRepo({this.error});
  final Object? error;
  final calls = <({String id, String? email})>[];

  @override
  Future<CreditCard> setClaimEmail(String id, String? email) async {
    calls.add((id: id, email: email));
    if (error != null) throw error!;
    return CardMapper.fromJson({...cardJson(), 'claimEmail': email});
  }
}

class _NoCards implements CardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    await initializeDateFormatting('en_US');
  });
  tearDown(Get.reset);

  late _Launcher launcher;
  late _ClaimRepo repo;
  late CardsController cards;
  String? clipboard;

  setUp(() {
    clipboard = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  });

  Future<ClaimController> pump(
    WidgetTester tester, {
    String appLang = 'es',
    String? claimEmail,
    bool mailApp = true,
    Object? saveError,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ActiveLocale.set(Locale(appLang));
    S.current = ActiveLocale.strings;
    launcher = _Launcher(result: mailApp);
    repo = _ClaimRepo(error: saveError);
    cards = CardsController(_NoCards())
      ..cards.assignAll([
        CardMapper.fromJson({...cardJson(), 'claimEmail': claimEmail}),
      ]);
    final verification = VerificationMapper.detail(verificationJson());
    final c = ClaimController(
      verification: verification,
      launcher: launcher,
      initialLanguage: ClaimLanguage.fromCode(appLang),
      card: cards.byId('c1'),
      userName: 'Ana Martínez',
      repository: repo,
      cards: cards,
    );
    Get.put<AppNavigator>(FakeNavigator());
    Get.put<ClaimController>(c);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(appLang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const ClaimPage(),
      ),
    );
    await tester.pump();
    return c;
  }

  String body(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('claim-body'))).data!;
  String subject(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('claim-subject'))).data!;

  testWidgets('shows the header, the controls and the real data (es)', (
    tester,
  ) async {
    await pump(tester, claimEmail: 'reclamos@bbva.mx');
    expect(find.text('Reclamo al banco'), findsOneWidget);
    expect(find.text('FUTURO'), findsNothing);
    expect(find.text('Idioma del correo'), findsOneWidget);
    expect(find.text('Tono'), findsOneWidget);
    expect(find.text('Formal'), findsOneWidget);
    expect(find.text('Firme'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('Abrir en Correo'), findsOneWidget);
    final summary = tester.widget<Text>(find.byKey(const Key('claim-summary')));
    expect(summary.data, contains('Daily •••• 4321'));
    expect(summary.data, contains('-MXN 18.00'));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('claim-to')))
          .controller!
          .text,
      'reclamos@bbva.mx',
    );
    expect(subject(tester), startsWith('Cashback no acreditado · tarjeta'));
    expect(body(tester), contains('Estimados señores de BBVA'));
    expect(body(tester), contains('Atentamente,\nAna Martínez'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the email language defaults to the app one and is independent', (
    tester,
  ) async {
    await pump(tester, appLang: 'en');
    expect(find.text('Claim to the bank'), findsOneWidget);
    expect(body(tester), startsWith('Dear BBVA team,'));
    // Switch the EMAIL to Spanish: the screen stays in English.
    await tester.tap(find.text('Español'));
    await tester.pump();
    expect(body(tester), startsWith('Estimados señores de BBVA'));
    expect(find.text('Claim to the bank'), findsOneWidget);
    // Tone to firm.
    await tester.tap(find.text('Firm'));
    await tester.pump();
    expect(body(tester), contains('no acredita el cashback'));
  });

  testWidgets('Copy puts subject and body on the clipboard and says so', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('claim-copy')));
    await tester.pump();
    await tester.pump();
    expect(clipboard, startsWith(subject(tester)));
    expect(clipboard, contains(body(tester)));
    expect(find.text('Correo copiado al portapapeles.'), findsOneWidget);
    expect(launcher.opened, isEmpty);
  });

  testWidgets('Open in Mail launches a mailto with to, subject and body', (
    tester,
  ) async {
    await pump(tester, claimEmail: 'reclamos@bbva.mx', appLang: 'en');
    await tester.tap(find.byKey(const Key('claim-open-mail')));
    await tester.pump();
    await tester.pump();
    expect(launcher.opened, hasLength(1));
    final uri = launcher.opened.single;
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'reclamos@bbva.mx');
    expect(uri.toString(), isNot(contains('+')));
    expect(uri.toString(), contains('subject=Uncredited%20cashback'));
    expect(uri.toString(), contains('%0A'));
    expect(uri.queryParameters['subject'], subject(tester));
    expect(uri.queryParameters['body'], body(tester));
    // Unchanged recipient: nothing is saved.
    expect(repo.calls, isEmpty);
  });

  testWidgets('a changed recipient is PATCHed on the card', (tester) async {
    final c = await pump(tester, claimEmail: 'old@bbva.mx');
    await tester.enterText(
      find.byKey(const Key('claim-to')),
      ' nuevo@bbva.mx ',
    );
    await tester.tap(find.byKey(const Key('claim-open-mail')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls.single.id, 'c1');
    expect(repo.calls.single.email, 'nuevo@bbva.mx');
    expect(c.card!.claimEmail, 'nuevo@bbva.mx');
    expect(cards.byId('c1')!.claimEmail, 'nuevo@bbva.mx');
    expect(launcher.opened.single.path, 'nuevo@bbva.mx');
    // Copying afterwards with the same value does not PATCH again.
    await tester.tap(find.byKey(const Key('claim-copy')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls, hasLength(1));
  });

  testWidgets('clearing the recipient sends null', (tester) async {
    await pump(tester, claimEmail: 'old@bbva.mx');
    await tester.enterText(find.byKey(const Key('claim-to')), '');
    await tester.tap(find.byKey(const Key('claim-copy')));
    await tester.pump();
    await tester.pump();
    expect(repo.calls.single.email, isNull);
  });

  testWidgets('a failed save still copies and tells the user', (tester) async {
    await pump(
      tester,
      saveError: const AppException(kind: AppErrorKind.network),
    );
    await tester.enterText(find.byKey(const Key('claim-to')), 'a@b.co');
    await tester.tap(find.byKey(const Key('claim-copy')));
    await tester.pump();
    await tester.pump();
    expect(clipboard, isNotNull);
    expect(
      find.textContaining('No pudimos guardar el correo en la tarjeta.'),
      findsOneWidget,
    );
  });

  testWidgets('an invalid recipient blocks the action with a message', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('claim-to')), 'no-es-correo');
    await tester.tap(find.byKey(const Key('claim-open-mail')));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Escribe un correo válido o déjalo vacío.'),
      findsOneWidget,
    );
    expect(launcher.opened, isEmpty);
    expect(repo.calls, isEmpty);
  });

  testWidgets('without a mail app it suggests Copy', (tester) async {
    await pump(tester, mailApp: false);
    await tester.tap(find.byKey(const Key('claim-open-mail')));
    await tester.pump();
    await tester.pump();
    expect(launcher.opened, hasLength(1));
    expect(find.textContaining('Usa Copiar'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('renders in a small phone (dark=$dark)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      await pump(tester, dark: dark);
      tester.view.physicalSize = const Size(320, 640);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
