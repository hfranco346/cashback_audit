import 'package:get/get.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/storage/token_storage.dart';
import '../../onboarding/domain/onboarding_repository.dart';

/// Decides the first route: onboarding, login or home.
class SplashController extends GetxController {
  SplashController({
    required this.onboarding,
    required this.tokens,
    this.minimumDelay = const Duration(milliseconds: 900),
  });

  final OnboardingRepository onboarding;
  final TokenStorage tokens;
  final Duration minimumDelay;

  Future<String> resolveRoute() async {
    final seen = await onboarding.hasSeenOnboarding();
    if (!seen) return Routes.onboarding;
    final stored = await tokens.read();
    return stored == null ? Routes.login : Routes.home;
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
    Get.offAllNamed(results.first as String);
  }
}
