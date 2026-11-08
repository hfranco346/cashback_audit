import 'package:cashback_audit/core/routing/app_routes.dart';
import 'package:cashback_audit/core/storage/token_storage.dart';
import 'package:cashback_audit/features/onboarding/domain/onboarding_repository.dart';
import 'package:cashback_audit/features/splash/presentation/splash_controller.dart';

import '../support/fakes.dart';

import 'package:flutter_test/flutter_test.dart';

class _FakeOnboarding implements OnboardingRepository {
  _FakeOnboarding(this.seen);
  bool seen;
  @override
  Future<bool> hasSeenOnboarding() async => seen;
  @override
  Future<void> markOnboardingSeen() async => seen = true;
}

void main() {
  SplashController build({required bool seen, AuthTokens? tokens}) =>
      SplashController(
        onboarding: _FakeOnboarding(seen),
        tokens: InMemoryTokenStorage(tokens),
        navigator: FakeNavigator(),
      );

  test('first launch goes to onboarding', () async {
    expect(await build(seen: false).resolveRoute(), Routes.onboarding);
  });

  test('seen onboarding without session goes to login', () async {
    expect(await build(seen: true).resolveRoute(), Routes.login);
  });

  test('stored session goes to home', () async {
    final c = build(
      seen: true,
      tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    expect(await c.resolveRoute(), Routes.home);
  });
}
