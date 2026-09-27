import 'package:flutter_test/flutter_test.dart';
import 'package:rated/screens/questionnaire/questionnaire_flow.dart';

/// Routing, validation and serialisation for questionnaire v3.
///
/// The eight routing cases here are mirrored by `requiredFields` in
/// `supabase/functions/seed-elo/seed_test.ts`. If you change a routing rule in
/// one place, the other test must change with it — that cross-reference is the
/// only practical defence against the Dart and TypeScript rules drifting.
void main() {
  /// Fully answered base steps, recreational by default.
  QuestionnaireAnswers recreational() => QuestionnaireAnswers()
    ..dateOfBirth = DateTime(1990, 6, 15)
    ..yearsPlaying = 8
    ..playFrequency = 'weekly'
    ..greekExperience = 'recreational'
    ..internationalExperience = 'none'
    ..tournamentsLast3y = false
    ..otherSport = 'none';

  QuestionnaireAnswers credentialed() => recreational()
    ..greekExperience = 'national_top20'
    ..otherSport = null;

  group('cohorts', () {
    test('recreational + no international experience is the recreational cohort',
        () {
      final a = recreational();
      expect(isRecreationalCohort(a), isTrue);
      expect(hasCredentials(a), isFalse);
    });

    test('recreational + recreational_intl stays in the recreational cohort',
        () {
      // The obvious-looking rule "intl != none means credentialed" would drop
      // this player into neither branch, flattening them to a single value.
      final a = recreational()..internationalExperience = 'recreational_intl';
      expect(isRecreationalCohort(a), isTrue);
      expect(activeSteps(a), contains(QStep.otherSport));
    });

    test('us_college is credentialed, not recreational', () {
      final a = recreational()
        ..internationalExperience = 'us_college'
        ..usCollegeDivision = 'division_3';
      expect(hasCredentials(a), isTrue);
      expect(activeSteps(a), isNot(contains(QStep.otherSport)));
    });

    test('any Greek credential is credentialed regardless of international', () {
      for (final g in greekExperienceValues.where((g) => g != 'recreational')) {
        final a = recreational()..greekExperience = g;
        expect(hasCredentials(a), isTrue, reason: g);
      }
    });

    test('the two cohorts are exact complements across the whole answer space',
        () {
      for (final g in greekExperienceValues) {
        for (final i in internationalExperienceValues) {
          final a = recreational()
            ..greekExperience = g
            ..internationalExperience = i;
          expect(isRecreationalCohort(a), !hasCredentials(a),
              reason: '$g / $i');
        }
      }
    });
  });

  group('activeSteps', () {
    test('an empty bag shows only the six base steps', () {
      expect(activeSteps(QuestionnaireAnswers()), [
        QStep.dob,
        QStep.years,
        QStep.frequency,
        QStep.greek,
        QStep.international,
        QStep.tournaments3y,
      ]);
    });

    test('the branch does not appear until both gating answers exist', () {
      final a = QuestionnaireAnswers()..greekExperience = 'recreational';
      // international still null — otherSport must not appear yet, or the step
      // count would jump around while the user is still on an earlier step.
      expect(activeSteps(a).length, 6);
    });

    test('credentialed + no tournaments is six steps', () {
      final a = credentialed();
      expect(activeSteps(a).length, 6);
      expect(activeSteps(a).last, QStep.tournaments3y);
    });

    test('credentialed + tournaments is eight steps', () {
      final a = credentialed()
        ..tournamentsLast3y = true
        ..tournamentsPerYear = 6
        ..tournamentLevel = 'open';
      expect(activeSteps(a), [
        QStep.dob,
        QStep.years,
        QStep.frequency,
        QStep.greek,
        QStep.international,
        QStep.tournaments3y,
        QStep.tournamentsPerYear,
        QStep.tournamentLevel,
      ]);
    });

    test('recreational + no tournaments is seven steps', () {
      expect(activeSteps(recreational()).length, 7);
      expect(activeSteps(recreational()).last, QStep.otherSport);
    });

    test('recreational + tournaments is nine steps', () {
      final a = recreational()
        ..tournamentsLast3y = true
        ..tournamentsPerYear = 4
        ..tournamentLevel = 'intermediate';
      expect(activeSteps(a).length, 9);
    });

    test('tournament volume and level are gated on the yes/no answer', () {
      final a = recreational()..tournamentsLast3y = false;
      expect(activeSteps(a), isNot(contains(QStep.tournamentsPerYear)));
      expect(activeSteps(a), isNot(contains(QStep.tournamentLevel)));

      a.tournamentsLast3y = true;
      expect(activeSteps(a), contains(QStep.tournamentsPerYear));
      expect(activeSteps(a), contains(QStep.tournamentLevel));
    });
  });

  group('pruneInactive', () {
    test('answering no to tournaments clears volume and level', () {
      final a = recreational()
        ..tournamentsLast3y = true
        ..tournamentsPerYear = 12
        ..tournamentLevel = 'master';

      a.tournamentsLast3y = false;
      pruneInactive(a);

      expect(a.tournamentsPerYear, isNull);
      expect(a.tournamentLevel, isNull);
    });

    test('switching to a credential clears other_sport', () {
      final a = recreational()..otherSport = 'racket_sports';

      a.greekExperience = 'national_20_200';
      pruneInactive(a);

      expect(a.otherSport, isNull);
    });

    test('switching back to recreational clears nothing it should keep', () {
      final a = credentialed()
        ..tournamentsLast3y = true
        ..tournamentsPerYear = 5
        ..tournamentLevel = 'amateur';

      a.greekExperience = 'recreational';
      pruneInactive(a);

      // The tournament block is universal, so it survives a cohort switch.
      expect(a.tournamentsPerYear, 5);
      expect(a.tournamentLevel, 'amateur');
      expect(activeSteps(a), contains(QStep.otherSport));
    });

    test('changing the international option clears the other sub-fields', () {
      final a = recreational()
        ..internationalExperience = 'junior_intl'
        ..juniorCareerHighRanking = 120
        ..receivedAtpWtaPoint = true
        ..usCollegeDivision = 'division_1';

      pruneInactive(a);
      expect(a.juniorCareerHighRanking, 120);
      expect(a.receivedAtpWtaPoint, isNull);
      expect(a.usCollegeDivision, isNull);

      a.internationalExperience = 'us_college';
      a.usCollegeDivision = 'division_2';
      pruneInactive(a);
      expect(a.juniorCareerHighRanking, isNull);
      expect(a.usCollegeDivision, 'division_2');

      a.internationalExperience = 'none';
      pruneInactive(a);
      expect(a.usCollegeDivision, isNull);
    });

    test('pruning leaves the step list valid to index with a single clamp', () {
      final a = recreational()
        ..tournamentsLast3y = true
        ..tournamentsPerYear = 3
        ..tournamentLevel = 'amateur';
      expect(activeSteps(a).length, 9);

      a.tournamentsLast3y = false;
      pruneInactive(a);
      final steps = activeSteps(a);
      expect(steps.length, 7);
      // A stale index of 8 clamps into range rather than throwing.
      expect(steps[(8).clamp(0, steps.length - 1)], QStep.otherSport);
    });
  });

  group('isStepValid', () {
    test('international requires the right sub-field for each option', () {
      final a = QuestionnaireAnswers()..internationalExperience = 'none';
      expect(isStepValid(QStep.international, a), isTrue);

      a.internationalExperience = 'recreational_intl';
      expect(isStepValid(QStep.international, a), isTrue);

      a.internationalExperience = 'junior_intl';
      expect(isStepValid(QStep.international, a), isFalse);
      a.juniorCareerHighRanking = 0;
      expect(isStepValid(QStep.international, a), isFalse);
      a.juniorCareerHighRanking = 150;
      expect(isStepValid(QStep.international, a), isTrue);

      a.internationalExperience = 'professional_adult';
      expect(isStepValid(QStep.international, a), isFalse);
      a.receivedAtpWtaPoint = false;
      expect(isStepValid(QStep.international, a), isTrue);

      a.internationalExperience = 'us_college';
      a.usCollegeDivision = null;
      expect(isStepValid(QStep.international, a), isFalse);
      // A v2-era display string is not a valid v3 value.
      a.usCollegeDivision = 'Division I';
      expect(isStepValid(QStep.international, a), isFalse);
      a.usCollegeDivision = 'division_1';
      expect(isStepValid(QStep.international, a), isTrue);

      a.internationalExperience = null;
      expect(isStepValid(QStep.international, a), isFalse);
    });

    test('tournaments per year is bounded', () {
      final a = QuestionnaireAnswers();
      for (final (n, ok) in [(null, false), (0, false), (1, true), (100, true), (101, false)]) {
        a.tournamentsPerYear = n;
        expect(isStepValid(QStep.tournamentsPerYear, a), ok, reason: '$n');
      }
    });

    test('years playing is bounded 0..80', () {
      final a = QuestionnaireAnswers();
      for (final (n, ok) in [(null, false), (-1, false), (0, true), (80, true), (81, false)]) {
        a.yearsPlaying = n;
        expect(isStepValid(QStep.years, a), ok, reason: '$n');
      }
    });

    test('enum steps reject values outside the allowed set', () {
      final a = QuestionnaireAnswers()..tournamentLevel = 'intensive';
      expect(isStepValid(QStep.tournamentLevel, a), isFalse);
      a.tournamentLevel = 'open';
      expect(isStepValid(QStep.tournamentLevel, a), isTrue);
    });

    test('isComplete requires every active step', () {
      final a = recreational();
      expect(isComplete(a), isTrue);

      a.tournamentsLast3y = true; // opens two more steps, both unanswered
      expect(isComplete(a), isFalse);

      a.tournamentsPerYear = 2;
      a.tournamentLevel = 'amateur';
      expect(isComplete(a), isTrue);
    });
  });

  group('age gate', () {
    final now = DateTime(2026, 9, 26);

    test('exactly 16 today is eligible, one day short is not', () {
      expect(isAgeEligible(DateTime(2010, 9, 26), now: now), isTrue);
      expect(isAgeEligible(DateTime(2010, 9, 27), now: now), isFalse);
    });

    test('90 is eligible, 91 is not', () {
      expect(isAgeEligible(DateTime(1936, 9, 26), now: now), isTrue);
      expect(isAgeEligible(DateTime(1935, 9, 25), now: now), isFalse);
    });

    test('age is not yet incremented the day before a birthday', () {
      expect(ageFromDob(DateTime(1990, 9, 27), now: now), 35);
      expect(ageFromDob(DateTime(1990, 9, 26), now: now), 36);
    });

    test('the dob step is invalid for an ineligible date', () {
      final a = QuestionnaireAnswers()..dateOfBirth = DateTime(2020, 1, 1);
      expect(isStepValid(QStep.dob, a), isFalse);
    });
  });

  group('toRequestBody', () {
    test('carries the version and an ISO date', () {
      final body = toRequestBody(recreational());
      expect(body['questionnaire_version'], kQuestionnaireVersion);
      expect(body['date_of_birth'], '1990-06-15');
    });

    test('emits explicit nulls for every routed-away question', () {
      final body = toRequestBody(credentialed());

      // Present as keys so the upsert clears any stale v2 value.
      for (final k in [
        'other_sport',
        'tournaments_per_year',
        'tournament_level',
        'junior_career_high_ranking',
        'received_atp_wta_point',
        'us_college_division',
      ]) {
        expect(body.containsKey(k), isTrue, reason: k);
        expect(body[k], isNull, reason: k);
      }
    });

    test('drops a stale answer that the current routing would not ask', () {
      // A user who answered other_sport, then claimed a national credential.
      final a = credentialed()..otherSport = 'racket_sports';
      expect(toRequestBody(a)['other_sport'], isNull);
    });

    test('sends the sub-field belonging to the selected option only', () {
      final a = recreational()
        ..internationalExperience = 'junior_intl'
        ..juniorCareerHighRanking = 88
        ..usCollegeDivision = 'division_1';

      final body = toRequestBody(a);
      expect(body['junior_career_high_ranking'], 88);
      expect(body['us_college_division'], isNull);
    });

    test('sends the full tournament block when it is active', () {
      final a = recreational()
        ..tournamentsLast3y = true
        ..tournamentsPerYear = 9
        ..tournamentLevel = 'age_category';

      final body = toRequestBody(a);
      expect(body['tournaments_last_3y'], isTrue);
      expect(body['tournaments_per_year'], 9);
      expect(body['tournament_level'], 'age_category');
    });

    test('lists every column the responses row holds', () {
      expect(toRequestBody(recreational()).keys.toSet(), {
        'questionnaire_version',
        'date_of_birth',
        'years_playing',
        'play_frequency',
        'greek_experience',
        'international_experience',
        'junior_career_high_ranking',
        'received_atp_wta_point',
        'us_college_division',
        'tournaments_last_3y',
        'tournaments_per_year',
        'tournament_level',
        'other_sport',
      });
    });
  });
}
