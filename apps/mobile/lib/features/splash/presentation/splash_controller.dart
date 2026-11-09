import 'package:get/get.dart';

import '../../../core/routing/app_navigator.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/storage/token_storage.dart';
import '../../onboarding/domain/onboarding_repository.dart';

/// Decides the first route: home (session), login or the guided setup.
class SplashController extends GetxController {
  SplashController({
    required this.onboarding,
    required this.tokens,
    required this.navigator,
    this.minimumDelay = const Duration(milliseconds: 900),
  });

  final OnboardingRepository onboarding;
  final TokenStorage tokens;
  final AppNavigator navigator;
  final Duration minimumDelay;

  Future<String> resolveRoute() async {
    // A stored session always wins: an interrupted setup resumes from Home.
    if (await tokens.read() != null) return Routes.home;
    final seen = await onboarding.hasSeenOnboarding();
    return seen ? Routes.login : Routes.onboarding;
  }

  @override
  void onReady() {
    super.onReady();
    _go();
  }

  Future<void> _go() async {
    final results = await Future.wait([
      resolveRoute(),
      Future<void>.delayed(minimumDelay),
    ]);
    navigator.offAll(results.first as String);
  }
}
