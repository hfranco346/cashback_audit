import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/l10n/active_locale.dart';
import '../../../core/l10n/strings.dart';
import '../domain/locale_preference.dart';

/// Permanent holder of the language choice (Automatic / Español / English).
/// Registered before the first frame (see `main.dart`). With
/// [LocalePreference.auto] it follows the phone's locale live.
class LocaleController extends GetxController with WidgetsBindingObserver {
  LocaleController({
    required this._repository,
    LocalePreference initial = LocalePreference.auto,
    Locale Function()? systemLocale,
    void Function(Locale locale)? applyLocale,
  }) : _systemLocale =
           systemLocale ?? (() => PlatformDispatcher.instance.locale),
       _applyLocale = applyLocale ?? Get.updateLocale,
       preference = initial.obs {
    _sync(locale);
  }

  final LocalePreferenceRepository _repository;
  final Locale Function() _systemLocale;
  final void Function(Locale locale) _applyLocale;
  final Rx<LocalePreference> preference;

  /// Locale in effect for the current preference and phone settings.
  Locale get locale => resolveLocale(preference.value, _systemLocale());

  /// Reads the stored preference; falls back to automatic on any failure.
  static Future<LocalePreference> loadInitial(
    LocalePreferenceRepository repository,
  ) async {
    try {
      return await repository.read();
    } on Object {
      return LocalePreference.auto;
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (preference.value == LocalePreference.auto) _apply();
  }

  Future<void> select(LocalePreference value) async {
    if (value == preference.value) return;
    preference.value = value;
    _apply();
    try {
      await _repository.save(value);
    } on Object {
      // Not persisting is acceptable: the choice still applies this session.
    }
  }

  void _apply() {
    final next = locale;
    if (next == ActiveLocale.locale) return;
    _sync(next);
    _applyLocale(next);
  }

  /// Updates the context-free readers (formatters and the legacy `S` layer).
  void _sync(Locale next) {
    ActiveLocale.set(next);
    S.current = ActiveLocale.strings;
  }
}
