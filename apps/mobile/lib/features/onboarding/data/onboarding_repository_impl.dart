import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl(this._prefs);

  static const _key = 'onboarding_seen';
  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> hasSeenOnboarding() async => await _prefs.getBool(_key) ?? false;

  @override
  Future<void> markOnboardingSeen() => _prefs.setBool(_key, true);
}
