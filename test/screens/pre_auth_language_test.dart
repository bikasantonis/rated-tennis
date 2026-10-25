import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/locale_provider.dart';
import 'package:rated/screens/auth/login_screen.dart';
import 'package:rated/screens/onboarding/onboarding_screen.dart';
import 'package:rated/theme/app_theme.dart';
import 'package:rated/widgets/language_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the real pre-auth screens with the language toggle in place.
///
/// The toggle went into a crowded app bar on SCR-02 and into a new header row
/// on SCR-01 — which re-wrapped the whole `LayoutBuilder` the slide/auth split
/// is derived from. An overflow or a broken split would greet every new player,
/// so both layouts are pumped at phone and desktop width.
///
/// Sign-in is never tapped: the auth actions reach `Supabase.instance`, which
/// is not initialised under test.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness(Widget home) => ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            // The real theme: Barlow Condensed / IBM Plex metrics are what the
            // overflow assertions below actually hinge on.
            theme: AppTheme.light,
            locale: ref.watch(localeProvider),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      );

  Future<void> pumpAt(WidgetTester tester, Widget home, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(harness(home));
    await tester.pumpAndSettle();
  }

  /// "Σύνδεση" labels both the tab and the sign-in button, so tab assertions
  /// are scoped to the `TabBar`.
  Finder tab(String label) => find.descendant(
        of: find.byType(TabBar),
        matching: find.text(label),
      );

  group('login / register (SCR-02)', () {
    testWidgets('carries the toggle beside the title on a phone',
        (tester) async {
      await pumpAt(tester, const LoginScreen(), const Size(390, 844));

      expect(find.byType(LanguageToggle), findsOneWidget);
      expect(find.text('RATED'), findsOneWidget);
      // Title, toggle and tabs coexist in the same app bar.
      expect(tab('Login'), findsOneWidget);
      expect(tab('Register'), findsOneWidget);
    });

    testWidgets('switching language relabels the tabs', (tester) async {
      await pumpAt(tester, const LoginScreen(), const Size(390, 844));

      await tester.tap(find.text('ΕΛ'));
      await tester.pumpAndSettle();

      expect(tab('Login'), findsNothing);
      expect(tab('Σύνδεση'), findsOneWidget);
      expect(tab('Εγγραφή'), findsOneWidget);
    });
  });

  group('onboarding (SCR-01)', () {
    /// The first slide's title stands in for "the slides rendered"; the tab bar
    /// for "the auth card rendered". Both panels must survive either layout.
    void expectBothPanels(WidgetTester tester) {
      final l = AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      )!;
      expect(find.byType(LanguageToggle), findsOneWidget);
      expect(find.text(l.onboardingTitle1), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    }

    testWidgets('narrow layout keeps the toggle, slides and auth card',
        (tester) async {
      await pumpAt(tester, const OnboardingScreen(), const Size(390, 844));
      expectBothPanels(tester);
    });

    testWidgets('wide layout keeps the side-by-side split', (tester) async {
      await pumpAt(tester, const OnboardingScreen(), const Size(1280, 900));
      expectBothPanels(tester);
    });

    testWidgets('switching language relabels the slides', (tester) async {
      await pumpAt(tester, const OnboardingScreen(), const Size(390, 844));
      final english = AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      )!
          .onboardingTitle1;
      expect(find.text(english), findsOneWidget);

      await tester.tap(find.text('ΕΛ'));
      await tester.pumpAndSettle();

      final greek = AppLocalizations.of(
        tester.element(find.byType(OnboardingScreen)),
      )!
          .onboardingTitle1;
      expect(greek, isNot(english));
      expect(find.text(greek), findsOneWidget);
    });
  });
}
