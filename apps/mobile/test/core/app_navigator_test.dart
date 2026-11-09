import 'package:cashback_audit/core/routing/app_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showNotice shows a snackbar through the app messenger', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    GetAppNavigator().showNotice('Hecho', 'Compras restauradas');
    await tester.pump();
    expect(find.text('Hecho'), findsOneWidget);
    expect(find.text('Compras restauradas'), findsOneWidget);
  });

  test('showNotice without an app is a no-op', () {
    expect(() => GetAppNavigator().showNotice('a', 'b'), returnsNormally);
  });
}
