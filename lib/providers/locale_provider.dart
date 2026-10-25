import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

const _kLocaleKey = 'locale_language_code';

/// Languages RATED ships translations for — keep in sync with
/// `supportedLocales` in `RatedApp`.
const kSupportedLanguageCodes = {'en', 'el'};

const kFallbackLocale = Locale('en');

/// First device / browser language RATED has translations for, else English.
/// Used until the player picks a language, so a Greek phone opens the app in
/// Greek instead of making them hunt for the switch.
/// Read through the binding rather than `PlatformDispatcher.instance` so the
/// platform's list can be overridden under test.
Locale deviceLocale() {
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    if (kSupportedLanguageCodes.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return kFallbackLocale;
}

/// True once the player has picked a language on this device. An explicit pick
/// outranks both the device language and the profile's stored preference —
/// see `localeSyncProvider`.
Future<bool> hasExplicitLocaleChoice() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kLocaleKey) != null;
}

/// Loads the persisted locale once at startup, falling back to the device
/// language.
@riverpod
Future<Locale> savedLocale(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLocaleKey);
  if (code != null && kSupportedLanguageCodes.contains(code)) {
    return Locale(code);
  }
  return deviceLocale();
}

/// Mutable locale state — initialised from [savedLocale].
@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    // Seed from the persisted value if already resolved, otherwise from the
    // device language so the very first frame is in the right language.
    return ref.watch(savedLocaleProvider).maybeWhen(
          data: (l) => l,
          orElse: deviceLocale,
        );
  }

  /// The player picked a language — persisted as an explicit choice.
  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }

  /// Applies the language stored on the signed-in profile. Deliberately not
  /// persisted: the profile row stays the source of truth and is refetched
  /// every session, so a later change made on another device still wins.
  void adoptProfileLocale(String code) {
    if (!kSupportedLanguageCodes.contains(code)) return;
    if (state.languageCode == code) return;
    state = Locale(code);
  }
}
