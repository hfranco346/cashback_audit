import 'package:cashback_audit/core/l10n/strings.dart';
import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/auth/presentation/login_controller.dart';
import 'package:cashback_audit/features/auth/presentation/widgets/login_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  testWidgets('smoke: renders title, Google and Apple buttons', (tester) async {
    var google = 0;
    await tester.pumpWidget(
      _wrap(
        LoginView(onGoogle: () => google++, onApple: () {}, showApple: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.loginTitle), findsOneWidget);
    expect(find.text(S.signInApple), findsOneWidget);
    await tester.tap(find.text(S.signInGoogle));
    expect(google, 1);
  });

  testWidgets('hides Apple when unsupported and shows errors', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LoginView(
          onGoogle: () {},
          onApple: () {},
          showApple: false,
          errorMessage: S.errNetwork,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(S.signInApple), findsNothing);
    expect(find.text(S.errNetwork), findsOneWidget);
  });

  testWidgets('disables buttons while a provider is loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        LoginView(
          onGoogle: () => taps++,
          onApple: () => taps++,
          showApple: true,
          loading: LoginProvider.google,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(S.signInApple), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('development sign-in button only shows with a callback', (
    tester,
  ) async {
    var dev = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginView(onGoogle: () {}, onApple: () {}, showApple: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dev-sign-in')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginView(
          onGoogle: () {},
          onApple: () {},
          showApple: false,
          onDevSignIn: () => dev++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dev-sign-in')));
    expect(dev, 1);
  });
}
