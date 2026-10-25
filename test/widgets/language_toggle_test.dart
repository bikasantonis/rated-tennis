import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/locale_provider.dart';
import 'package:rated/widgets/language_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the pre-auth language switch and the first-launch default.
///
/// The harness wires `localeProvider` into `MaterialApp.locale` exactly as
/// `RatedApp` does, so these assertions read a real translated string back out
/// of the tree — proof the whole loop works, not just that a pill repaints.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness() => ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeProvider),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  // Stands in for the login screen's title: an l10n string that
                  // differs between the two languages.
                  title: Text(AppLocalizations.of(context)!.settingsLanguageLabel),
                  actions: const [LanguageToggle()],
                ),
              ),
            ),
          ),
        ),
      );

  /// Pins the device language so the default-resolution tests are not at the
  /// mercy of the machine running them.
  void deviceLanguages(WidgetTester tester, List<Locale> locales) {
    tester.platformDispatcher.localesTestValue = locales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  testWidgets('offers both languages side by side', (tester) async {
    deviceLanguages(tester, const [Locale('en', 'US')]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('EN'), findsOneWidget);
    expect(find.text('ΕΛ'), findsOneWidget);
  });

  testWidgets('tapping ΕΛ switches the app to Greek and records the choice',
      (tester) async {
    deviceLanguages(tester, const [Locale('en', 'US')]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('ΕΛ'));
    await tester.pumpAndSettle();

    expect(find.text('Γλώσσα'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    // Explicit picks outrank the device language and the profile row.
    expect(await hasExplicitLocaleChoice(), isTrue);
  });

  testWidgets('tapping back to EN returns to English', (tester) async {
    deviceLanguages(tester, const [Locale('el', 'GR')]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Γλώσσα'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
  });

  group('first launch, before any choice', () {
    testWidgets('a Greek device opens in Greek', (tester) async {
      deviceLanguages(tester, const [Locale('el', 'GR')]);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Γλώσσα'), findsOneWidget);
      expect(await hasExplicitLocaleChoice(), isFalse);
    });

    testWidgets('an unsupported device language falls back to English',
        (tester) async {
      deviceLanguages(tester, const [Locale('de', 'DE')]);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsOneWidget);
    });

    testWidgets('a supported language further down the list still wins',
        (tester) async {
      deviceLanguages(tester, const [Locale('de', 'DE'), Locale('el', 'GR')]);
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      expect(find.text('Γλώσσα'), findsOneWidget);
    });
  });

  testWidgets('a saved choice survives a restart and beats the device language',
      (tester) async {
    SharedPreferences.setMockInitialValues({'locale_language_code': 'el'});
    deviceLanguages(tester, const [Locale('en', 'US')]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Γλώσσα'), findsOneWidget);
  });
}
