import 'package:cashback_audit/core/theme/app_theme.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_repository.dart';
import 'package:cashback_audit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:cashback_audit/features/onboarding/presentation/widgets/onboarding_slide_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';

class _Repo implements OnboardingRepository {
  bool seen = false;
  @override
  Future<bool> hasSeenOnboarding() async => seen;
  @override
  Future<void> markOnboardingSeen() async => seen = true;
}

void main() {
  testWidgets('slide view shows icon, title and body', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: OnboardingSlideView(
            icon: Icons.lock_outline_rounded,
            title: 'Titulo',
            body: 'Cuerpo del mensaje',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Titulo'), findsOneWidget);
    expect(find.text('Cuerpo del mensaje'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  test(
    'controller tracks pages and persists the seen flag on finish',
    () async {
      final repo = _Repo();
      final nav = FakeNavigator();
      final c = OnboardingController(repository: repo, navigator: nav);
      expect(OnboardingController.slides.length, greaterThanOrEqualTo(3));
      expect(c.isLast, isFalse);
      c.onPageChanged(OnboardingController.slides.length - 1);
      expect(c.isLast, isTrue);
      await c.next(); // last page -> finish
      expect(repo.seen, isTrue);
      expect(nav.routes, ['/login']);
      c.pageController.dispose();
    },
  );
}
