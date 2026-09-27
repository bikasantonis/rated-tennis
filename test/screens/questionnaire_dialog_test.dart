import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/screens/questionnaire/questionnaire_screen.dart';

/// Renders the real dialog and walks both routing branches.
///
/// The routing rules themselves are covered by
/// `test/models/questionnaire_flow_test.dart`; what this adds is proof that the
/// widget tree actually builds for every step and that navigation advances
/// through the derived step list. The dialog was rewritten from a `PageView`
/// with fixed page indices to an `AnimatedSwitcher` over a variable-length list,
/// so a build or layout failure here would break onboarding for every new
/// player while every pure unit test still passed.
///
/// Submission is deliberately never tapped — it calls the `seed-elo` Edge
/// Function through `Supabase.instance`, which is not initialised under test.
void main() {
  Widget harness() => ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: QuestionnaireDialog()),
        ),
      );

  /// The dialog is 560x700 at most; give it room so overflow errors are real
  /// findings rather than artefacts of the default 800x600 test surface.
  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester tester) => AppLocalizations.of(
        tester.element(find.byType(QuestionnaireDialog)),
      )!;

  /// Reads the "Step N of T" label back, so assertions track what the widget
  /// actually derived rather than a number hard-coded in the test.
  (int current, int total) progress(WidgetTester tester) {
    final text = tester
        .widgetList<Text>(find.textContaining(RegExp(r'^Step \d+ of \d+$')))
        .first
        .data!;
    final m = RegExp(r'^Step (\d+) of (\d+)$').firstMatch(text)!;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, l(tester).actionNext));
    await tester.pumpAndSettle();
  }

  /// Answers the date-of-birth step via the Material picker. `initialDate` is
  /// 1990, comfortably inside the 16–90 window, so accepting the default is a
  /// valid answer. The confirm label is read from MaterialLocalizations so this
  /// works under the Greek locale too.
  Future<void> answerDob(WidgetTester tester) async {
    final ok = MaterialLocalizations.of(
      tester.element(find.byType(QuestionnaireDialog)),
    ).okButtonLabel;
    await tester.tap(find.text(l(tester).questionnaireDobPlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
  }

  Future<void> answerNumber(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.pumpAndSettle();
  }

  /// Steps scroll (the international step in particular, once an inline
  /// sub-question has expanded), so options are brought into view first — the
  /// same thing a real user does.
  Future<void> tapOption(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// dob → years → frequency, leaving the Greek-experience step on screen.
  Future<void> answerCommonPrefix(WidgetTester tester) async {
    await answerDob(tester);
    await tapNext(tester);
    await answerNumber(tester, '12');
    await tapNext(tester);
    await tapOption(tester, l(tester).questionnaireFrequencyWeekly);
    await tapNext(tester);
  }

  testWidgets('opens on the date-of-birth step with Next disabled', (t) async {
    await pumpDialog(t);

    expect(find.text(l(t).questionnaireDobTitle), findsOneWidget);
    expect(progress(t), (1, 6));

    final next = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, l(t).actionNext),
    );
    expect(next.onPressed, isNull,
        reason: 'Next must stay disabled until the step is answered');

    // No Back button on the first step.
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('credentialed branch renders six steps and skips the '
      'recreational tail', (t) async {
    await pumpDialog(t);
    await answerCommonPrefix(t);

    await tapOption(t, l(t).questionnaireGreekNationalTop20);
    await tapNext(t);

    expect(find.text(l(t).questionnaireIntlTitle), findsOneWidget);
    await tapOption(t, l(t).questionnaireIntlNone);
    await tapNext(t);

    // Tournament gate, and the last step for a credentialed player who says no.
    expect(find.text(l(t).questionnaireTournamentsTitle), findsOneWidget);
    expect(find.text(l(t).questionnaireTournamentsSub), findsOneWidget);
    await tapOption(t, l(t).actionNo);

    expect(progress(t), (6, 6));
    expect(find.widgetWithText(FilledButton, l(t).questionnaireGetMyRating),
        findsOneWidget,
        reason: 'six steps is the whole questionnaire for this cohort');
    // other_sport must never be reachable here.
    expect(find.text(l(t).questionnaireOtherSportTitle), findsNothing);
  });

  testWidgets('recreational branch appends the other-sport step', (t) async {
    await pumpDialog(t);
    await answerCommonPrefix(t);

    await tapOption(t, l(t).questionnaireGreekRecreational);
    await tapNext(t);
    await tapOption(t, l(t).questionnaireIntlNone);
    await tapNext(t);

    expect(progress(t), (6, 7));
    await tapOption(t, l(t).actionNo);
    await tapNext(t);

    expect(find.text(l(t).questionnaireOtherSportTitle), findsOneWidget);
    expect(progress(t), (7, 7));
  });

  testWidgets('answering yes to tournaments inserts volume and level',
      (t) async {
    await pumpDialog(t);
    await answerCommonPrefix(t);

    await tapOption(t, l(t).questionnaireGreekRecreational);
    await tapNext(t);
    await tapOption(t, l(t).questionnaireIntlNone);
    await tapNext(t);

    // Yes opens two more steps, so the recreational total goes 7 → 9.
    await tapOption(t, l(t).actionYes);
    expect(progress(t), (6, 9));
    await tapNext(t);

    expect(find.text(l(t).questionnaireTournamentsPerYearTitle), findsOneWidget);
    await answerNumber(t, '8');
    await tapNext(t);

    expect(find.text(l(t).questionnaireTournamentLevelTitle), findsOneWidget);
    // All five rungs render, including the `open` rung added for v3.
    for (final label in [
      l(t).questionnaireLevelAmateur,
      l(t).questionnaireLevelIntermediate,
      l(t).questionnaireLevelAgeCategory,
      l(t).questionnaireLevelMaster,
      l(t).questionnaireLevelOpen,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tapOption(t, l(t).questionnaireLevelOpen);
    await tapNext(t);

    expect(find.text(l(t).questionnaireOtherSportTitle), findsOneWidget);
    expect(progress(t), (9, 9));
  });

  testWidgets('switching cohort after answering the tail clears it and keeps '
      'the index in range', (t) async {
    await pumpDialog(t);
    await answerCommonPrefix(t);

    // Recreational, no tournaments, answer the final other-sport step.
    await tapOption(t, l(t).questionnaireGreekRecreational);
    await tapNext(t);
    await tapOption(t, l(t).questionnaireIntlNone);
    await tapNext(t);
    await tapOption(t, l(t).actionNo);
    await tapNext(t);
    await tapOption(t, l(t).questionnaireOtherSportRacket);
    expect(progress(t), (7, 7));

    // Walk back to the Greek step and claim a credential.
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byType(OutlinedButton));
      await t.pumpAndSettle();
    }
    expect(find.text(l(t).questionnaireGreekTitle), findsOneWidget);

    await tapOption(t, l(t).questionnaireGreekNationalTop20);
    await t.pumpAndSettle();

    // The tail collapsed from three steps to none; the questionnaire is six
    // steps again and the index is still valid.
    expect(progress(t).$2, 6);
    expect(progress(t).$1, lessThanOrEqualTo(6));

    // Forward again: other_sport is gone, so the tournament gate is last.
    await tapNext(t);
    await tapNext(t);
    expect(find.text(l(t).questionnaireTournamentsTitle), findsOneWidget);
    expect(progress(t), (6, 6));
    expect(find.text(l(t).questionnaireOtherSportTitle), findsNothing);
  });

  testWidgets('international sub-questions appear inline and gate Next',
      (t) async {
    await pumpDialog(t);
    await answerCommonPrefix(t);
    await tapOption(t, l(t).questionnaireGreekRecreational);
    await tapNext(t);

    // Junior international requires a career-high ranking before advancing.
    await tapOption(t, l(t).questionnaireIntlJunior);
    expect(find.text(l(t).questionnaireIntlCareerHighHelper), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, l(t).actionNext))
          .onPressed,
      isNull,
      reason: 'the ranking sub-field is required for junior_intl',
    );

    // US College shows localised division pills over slug values.
    await tapOption(t, l(t).questionnaireIntlCollege);
    expect(find.text(l(t).questionnaireIntlCollegeDivision), findsOneWidget);
    for (final d in [
      l(t).questionnaireDivision1,
      l(t).questionnaireDivisionNaia,
      l(t).questionnaireDivisionNjcaa,
    ]) {
      expect(find.text(d), findsOneWidget, reason: d);
    }

    await tapOption(t, l(t).questionnaireDivision1);
    expect(
      t
          .widget<FilledButton>(
              find.widgetWithText(FilledButton, l(t).actionNext))
          .onPressed,
      isNotNull,
    );

    // us_college is credentialed, so the recreational tail stays away.
    await tapNext(t);
    expect(find.text(l(t).questionnaireTournamentsTitle), findsOneWidget);
    expect(progress(t), (6, 6));
  });

  testWidgets('renders in Greek without overflowing', (t) async {
    // The Greek copy is materially longer than the English — the tournament
    // question and its scope subtitle especially — so this is where a layout
    // overflow would show up. pumpAndSettle throws on a RenderFlex overflow.
    t.view.physicalSize = const Size(1200, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('el'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: QuestionnaireDialog()),
        ),
      ),
    );
    await t.pumpAndSettle();

    final el = l(t);
    expect(el.questionnaireDobTitle, isNot(equals('')));
    expect(find.text(el.questionnaireDobTitle), findsOneWidget);

    await answerDob(t);
    await tapNext(t);
    await answerNumber(t, '12');
    await tapNext(t);
    await tapOption(t, el.questionnaireFrequencyWeekly);
    await tapNext(t);
    await tapOption(t, el.questionnaireGreekRecreational);
    await tapNext(t);
    await tapOption(t, el.questionnaireIntlNone);
    await tapNext(t);

    // The longest screen in either language.
    expect(find.text(el.questionnaireTournamentsTitle), findsOneWidget);
    expect(find.text(el.questionnaireTournamentsSub), findsOneWidget);
    await tapOption(t, el.actionYes);
    await tapNext(t);
    await answerNumber(t, '8');
    await tapNext(t);
    for (final label in [
      el.questionnaireLevelAmateur,
      el.questionnaireLevelAgeCategory,
      el.questionnaireLevelOpen,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
