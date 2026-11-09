import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/onboarding_draft.dart';

class OnboardingDraftRepositoryImpl implements OnboardingDraftRepository {
  OnboardingDraftRepositoryImpl(this._prefs);

  static const _draftKey = 'onboarding_draft';
  static const _freshKey = 'onboarding_just_finished';
  final SharedPreferencesAsync _prefs;

  @override
  Future<OnboardingDraft?> read() async {
    try {
      final raw = await _prefs.getString(_draftKey);
      if (raw == null) return null;
      return OnboardingDraft.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      return null; // A corrupted draft is just a fresh start.
    }
  }

  @override
  Future<void> save(OnboardingDraft draft) =>
      _prefs.setString(_draftKey, jsonEncode(draft.toJson()));

  @override
  Future<void> clear() => _prefs.remove(_draftKey);

  @override
  Future<bool> isJustOnboarded() async =>
      await _prefs.getBool(_freshKey) ?? false;

  @override
  Future<void> setJustOnboarded(bool value) =>
      value ? _prefs.setBool(_freshKey, true) : _prefs.remove(_freshKey);
}
