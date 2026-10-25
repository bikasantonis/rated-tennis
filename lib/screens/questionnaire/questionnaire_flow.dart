// Pure routing, validation and serialisation logic for the onboarding
// questionnaire (v3). Deliberately free of Flutter imports so the whole file is
// unit-testable from `test/models/` — the only directory `pr.yml` runs.
//
// The TypeScript mirror of these routing rules lives in
// `supabase/functions/seed-elo/seed.ts` (`requiredFields`). The two must stay in
// step: a question that is routed away here must not be required there, and
// vice versa. `test/models/questionnaire_flow_test.dart` and
// `supabase/functions/seed-elo/seed_test.ts` cover the same eight cases.

/// Bumped whenever the question set changes. `profiles.questionnaire_version`
/// holds the version a player last completed; anything lower means a retake is
/// due. 0 = never taken, 2 = questionnaire v2 (migration 021).
const int kQuestionnaireVersion = 3;

/// Age bounds enforced on the date-of-birth step and again in `seed-elo`.
const int kMinAge = 16;
const int kMaxAge = 90;

// ── Allowed values (mirrored by the CHECK constraints in migration 030) ───────

const playFrequencyValues = ['rarely', 'monthly', 'weekly', 'multiple_weekly'];

const greekExperienceValues = [
  'recreational',
  'national_u200',
  'national_20_200',
  'national_top20',
];

const internationalExperienceValues = [
  'none',
  'recreational_intl',
  'junior_intl',
  'professional_adult',
  'us_college',
];

/// Ascending in standard of play: `open` (open / national draws) is the top rung.
const tournamentLevelValues = [
  'amateur',
  'intermediate',
  'age_category',
  'master',
  'open',
];

const otherSportValues = ['racket_sports', 'other_sports', 'none'];

/// Slugs, not display strings. Migration 030 normalises the v2 rows, which
/// stored the rendered English label ('Division I') as the value.
const usCollegeDivisionValues = [
  'division_1',
  'division_2',
  'division_3',
  'naia',
  'njcaa',
];

const tournamentsPerYearMin = 1;
const tournamentsPerYearMax = 100;
const yearsPlayingMax = 80;

// ── Steps ─────────────────────────────────────────────────────────────────────

enum QStep {
  dob,
  years,
  frequency,
  greek,
  international,
  tournaments3y,
  tournamentsPerYear,
  tournamentLevel,
  otherSport,
}

/// Mutable answer bag held by the dialog's `State`. Not freezed on purpose:
/// every mutation happens inside `setState`, so `copyWith` would add noise
/// without buying immutability that anything relies on.
class QuestionnaireAnswers {
  QuestionnaireAnswers();

  DateTime? dateOfBirth;
  int? yearsPlaying;
  String? playFrequency;
  String? greekExperience;
  String? internationalExperience;
  int? juniorCareerHighRanking;
  bool? receivedAtpWtaPoint;
  String? usCollegeDivision;
  bool? tournamentsLast3y;
  int? tournamentsPerYear;
  String? tournamentLevel;
  String? otherSport;
}

// ── Cohorts ───────────────────────────────────────────────────────────────────

/// True when the player holds no competitive credential — the cohort whose seed
/// comes from the tournament ladder rather than a credential base.
///
/// This and [hasCredentials] are exact complements once both gating answers
/// exist, so no answer combination can fall through both branches or neither.
bool isRecreationalCohort(QuestionnaireAnswers a) =>
    a.greekExperience == 'recreational' &&
    (a.internationalExperience == 'none' ||
        a.internationalExperience == 'recreational_intl');

bool hasCredentials(QuestionnaireAnswers a) => !isRecreationalCohort(a);

// ── Routing ───────────────────────────────────────────────────────────────────

const _baseSteps = [
  QStep.dob,
  QStep.years,
  QStep.frequency,
  QStep.greek,
  QStep.international,
  QStep.tournaments3y,
];

/// The ordered steps this player must answer, given what they have answered so
/// far.
///
/// Branch steps only append once their gating answer exists, so the list is
/// always a prefix of itself while the user is still inside the base steps.
/// Combined with the fact that a step can only be mutated while it is on
/// screen, that makes the current index invalidatable only by shrinkage — which
/// callers handle with a single clamp (see `pruneInactive`).
List<QStep> activeSteps(QuestionnaireAnswers a) {
  final steps = [..._baseSteps];

  // Volume and standard only make sense for someone who plays tournaments.
  if (a.tournamentsLast3y == true) {
    steps.add(QStep.tournamentsPerYear);
    steps.add(QStep.tournamentLevel);
  }

  // Another competitive sport only moves the needle on the recreational ladder;
  // for a credentialed player it cannot change the result, so it is not asked.
  if (a.greekExperience != null &&
      a.internationalExperience != null &&
      isRecreationalCohort(a)) {
    steps.add(QStep.otherSport);
  }

  return steps;
}

/// Whether [s] has a complete, in-range answer. Drives the Next button, the
/// progress label and the submit guard — there are no page-index switches left.
bool isStepValid(QStep s, QuestionnaireAnswers a) => switch (s) {
      QStep.dob => a.dateOfBirth != null && isAgeEligible(a.dateOfBirth!),
      QStep.years => a.yearsPlaying != null &&
          a.yearsPlaying! >= 0 &&
          a.yearsPlaying! <= yearsPlayingMax,
      QStep.frequency => playFrequencyValues.contains(a.playFrequency),
      QStep.greek => greekExperienceValues.contains(a.greekExperience),
      QStep.international => switch (a.internationalExperience) {
          'junior_intl' => (a.juniorCareerHighRanking ?? 0) > 0,
          'professional_adult' => a.receivedAtpWtaPoint != null,
          'us_college' =>
            usCollegeDivisionValues.contains(a.usCollegeDivision),
          'none' || 'recreational_intl' => true,
          _ => false,
        },
      QStep.tournaments3y => a.tournamentsLast3y != null,
      QStep.tournamentsPerYear => a.tournamentsPerYear != null &&
          a.tournamentsPerYear! >= tournamentsPerYearMin &&
          a.tournamentsPerYear! <= tournamentsPerYearMax,
      QStep.tournamentLevel =>
        tournamentLevelValues.contains(a.tournamentLevel),
      QStep.otherSport => otherSportValues.contains(a.otherSport),
    };

/// Whether every active step is answered — the submit precondition.
bool isComplete(QuestionnaireAnswers a) =>
    activeSteps(a).every((s) => isStepValid(s, a));

/// Nulls every answer whose step is no longer reachable, so a de-selection can
/// never leave a stale value behind to be persisted or scored.
///
/// Replaces the ad-hoc resets that used to live in `_onGreekChanged` /
/// `_onIntlChanged` and the hard-coded `jumpToPage(3)` correction.
void pruneInactive(QuestionnaireAnswers a) {
  final active = activeSteps(a).toSet();

  if (!active.contains(QStep.tournamentsPerYear)) a.tournamentsPerYear = null;
  if (!active.contains(QStep.tournamentLevel)) a.tournamentLevel = null;
  if (!active.contains(QStep.otherSport)) a.otherSport = null;

  // The three international sub-fields share one step, so they are pruned by
  // which option is selected rather than by step membership.
  switch (a.internationalExperience) {
    case 'junior_intl':
      a.receivedAtpWtaPoint = null;
      a.usCollegeDivision = null;
    case 'professional_adult':
      a.juniorCareerHighRanking = null;
      a.usCollegeDivision = null;
    case 'us_college':
      a.juniorCareerHighRanking = null;
      a.receivedAtpWtaPoint = null;
    default:
      a.juniorCareerHighRanking = null;
      a.receivedAtpWtaPoint = null;
      a.usCollegeDivision = null;
  }
}

// ── Age ───────────────────────────────────────────────────────────────────────

/// Completed years between [dob] and [now] (defaults to the current date).
int ageFromDob(DateTime dob, {DateTime? now}) {
  final today = now ?? DateTime.now();
  var age = today.year - dob.year;
  if (today.month < dob.month ||
      (today.month == dob.month && today.day < dob.day)) {
    age--;
  }
  return age;
}

/// Mirrors the gate in `seed-elo` so an ineligible date is caught on the first
/// step instead of after the whole questionnaire has been answered.
bool isAgeEligible(DateTime dob, {DateTime? now}) {
  final age = ageFromDob(dob, now: now);
  return age >= kMinAge && age <= kMaxAge;
}

// ── Serialisation ─────────────────────────────────────────────────────────────

/// The `seed-elo` request body.
///
/// Every column is listed, with an explicit `null` for any question the routing
/// did not ask. The Edge Function upserts the whole row, so an omitted key would
/// leave a retaker's stale v2 answer in place — for example an `other_sport`
/// value belonging to a player who has since claimed a national credential.
Map<String, dynamic> toRequestBody(QuestionnaireAnswers a) {
  final active = activeSteps(a).toSet();
  String? only(QStep s, String? v) => active.contains(s) ? v : null;

  return {
    'questionnaire_version': kQuestionnaireVersion,
    'date_of_birth': a.dateOfBirth?.toIso8601String().substring(0, 10),
    'years_playing': a.yearsPlaying,
    'play_frequency': a.playFrequency,
    'greek_experience': a.greekExperience,
    'international_experience': a.internationalExperience,
    'junior_career_high_ranking':
        a.internationalExperience == 'junior_intl'
            ? a.juniorCareerHighRanking
            : null,
    'received_atp_wta_point': a.internationalExperience == 'professional_adult'
        ? a.receivedAtpWtaPoint
        : null,
    'us_college_division': a.internationalExperience == 'us_college'
        ? a.usCollegeDivision
        : null,
    'tournaments_last_3y': a.tournamentsLast3y,
    'tournaments_per_year':
        active.contains(QStep.tournamentsPerYear) ? a.tournamentsPerYear : null,
    'tournament_level': only(QStep.tournamentLevel, a.tournamentLevel),
    'other_sport': only(QStep.otherSport, a.otherSport),
  };
}
