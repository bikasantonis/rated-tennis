import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'locale_provider.g.dart';

const _kLocaleKey = 'locale_language_code';

/// Loads the persisted locale once at startup.
@riverpod
Future<Locale> savedLocale(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kLocaleKey);
  return code != null ? Locale(code) : const Locale('en');
}

/// Mutable locale state — initialised from [savedLocale].
@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    // Seed from persisted value if already resolved, otherwise default to EN.
    return ref.watch(savedLocaleProvider).maybeWhen(
          data: (l) => l,
          orElse: () => const Locale('en'),
        );
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, locale.languageCode);
  }
}
