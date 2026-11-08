abstract class OnboardingRepository {
  Future<bool> hasSeenOnboarding();
  Future<void> markOnboardingSeen();
}
