// Seed-ELO algorithm — pure module, no supabase-js / Deno.env / Deno.serve.
// Kept free of side effects so `seed_test.ts` can run with `deno test` and no
// permission flags. The HTTP handler lives in `index.ts`.
//
// The routing rules here mirror `lib/screens/questionnaire/questionnaire_flow.dart`
// (`activeSteps` / `isStepValid`). A question routed away there must not be
// required by `requiredFields` here, and vice versa.
//
// Arithmetic note: every base and modifier is a multiple of 0.05, so the whole
// computation runs in **integer hundredths** and only converts to a decimal at
// the end. Adding 0.15 to 6.0 in binary floating point yields 6.149999999999999,
// which would round down to 6.1 instead of 6.2 — working in integers removes
// that class of bug entirely.

export type Division =
  | "division_1"
  | "division_2"
  | "division_3"
  | "naia"
  | "njcaa";

export interface V2Answers {
  dateOfBirth: string;
  yearsPlaying: number;
  greekExperience: string;
  internationalExperience: string;
  juniorCareerHighRanking?: number | null;
  receivedAtpWtaPoint?: boolean | null;
  usCollegeDivision?: string | null;
  otherSport?: string | null;
}

export interface V3Answers extends V2Answers {
  playFrequency: string;
  tournamentsLast3y: boolean;
  tournamentsPerYear?: number | null;
  tournamentLevel?: string | null;
}

export const MIN_ELO = 5.0;
export const MAX_ELO = 10.0;
export const MIN_AGE = 16;
export const MAX_AGE = 90;

/** Cohort B can never out-seed a genuinely ranked player's active range. */
export const RECREATIONAL_CEILING = 7.5;

/**
 * Ceiling for a recreational player who has not entered a tournament in three
 * years, and — deliberately the same number — for one who enters at most two a
 * year. Two events a year is barely a signal, so it earns the same ceiling as
 * none rather than a lower one: if this cap sat below [NO_TOURNAMENT_CAP],
 * entering a couple of tournaments could score *worse* than entering none.
 */
export const NO_TOURNAMENT_CAP = 6.8;
export const LOW_VOLUME_CAP = 6.8;
/** At or below this many tournaments a year, [LOW_VOLUME_CAP] applies. */
export const LOW_VOLUME_THRESHOLD = 2;

export const PLAY_FREQUENCIES = [
  "rarely",
  "monthly",
  "weekly",
  "multiple_weekly",
] as const;

export const GREEK_EXPERIENCES = [
  "recreational",
  "national_u200",
  "national_20_200",
  "national_top20",
] as const;

export const INTERNATIONAL_EXPERIENCES = [
  "none",
  "recreational_intl",
  "junior_intl",
  "professional_adult",
  "us_college",
] as const;

/** Ascending in standard of play. `open` (open / national draws) is the top rung. */
export const TOURNAMENT_LEVELS = [
  "amateur",
  "intermediate",
  "age_category",
  "master",
  "open",
] as const;

export const OTHER_SPORTS = ["racket_sports", "other_sports", "none"] as const;

export const DIVISIONS: Division[] = [
  "division_1",
  "division_2",
  "division_3",
  "naia",
  "njcaa",
];

export const TOURNAMENTS_PER_YEAR_MIN = 1;
export const TOURNAMENTS_PER_YEAR_MAX = 100;
export const YEARS_PLAYING_MAX = 80;

// ── Age ───────────────────────────────────────────────────────────────────────

/**
 * Completed years between `dateOfBirth` and `now`.
 *
 * `now` is injected so tests are deterministic — the v2 implementation called
 * `new Date()` internally and could not be tested across a birthday boundary.
 */
export function ageFromDob(dateOfBirth: string, now: Date = new Date()): number {
  const dob = new Date(dateOfBirth);
  let age = now.getFullYear() - dob.getFullYear();
  const m = now.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) age--;
  return age;
}

// ── Cohorts ───────────────────────────────────────────────────────────────────

/**
 * True when the player holds no competitive credential.
 *
 * This is the exact complement of "credentialed": the pair covers every
 * combination of the two experience answers, so nobody can fall through both
 * branches or neither. In particular `recreational` + `recreational_intl`
 * (ITF Masters and similar) belongs here, where the international record becomes
 * a modifier on the tournament ladder rather than a terminal value.
 */
export function isRecreationalCohort(
  a: Pick<V2Answers, "greekExperience" | "internationalExperience">,
): boolean {
  return a.greekExperience === "recreational" &&
    (a.internationalExperience === "none" ||
      a.internationalExperience === "recreational_intl");
}

export function hasCredentials(
  a: Pick<V2Answers, "greekExperience" | "internationalExperience">,
): boolean {
  return !isRecreationalCohort(a);
}

// ── Validation ────────────────────────────────────────────────────────────────

/** The v3 fields this answer set must carry, given its own routing. */
export function requiredFields(a: Partial<V3Answers>): string[] {
  const req = [
    "dateOfBirth",
    "yearsPlaying",
    "playFrequency",
    "greekExperience",
    "internationalExperience",
    "tournamentsLast3y",
  ];

  if (a.internationalExperience === "junior_intl") {
    req.push("juniorCareerHighRanking");
  }
  if (a.internationalExperience === "professional_adult") {
    req.push("receivedAtpWtaPoint");
  }
  if (a.internationalExperience === "us_college") {
    req.push("usCollegeDivision");
  }
  if (a.tournamentsLast3y === true) {
    req.push("tournamentsPerYear", "tournamentLevel");
  }
  if (
    a.greekExperience !== undefined && a.internationalExperience !== undefined &&
    isRecreationalCohort(a as V2Answers)
  ) {
    req.push("otherSport");
  }

  return req;
}

/** Maps v2 display strings onto v3 slugs. Idempotent; passes slugs through. */
export function normaliseCollegeDivision(v: unknown): string | null {
  if (typeof v !== "string" || v.length === 0) return null;
  switch (v) {
    case "Division I":
      return "division_1";
    case "Division II":
      return "division_2";
    case "Division III":
      return "division_3";
    case "NAIA":
      return "naia";
    case "NJCAA":
      return "njcaa";
    default:
      return v;
  }
}

/** Returns an error message, or null when the answers are usable. */
export function validate(
  a: Partial<V3Answers>,
  version: 2 | 3,
  now: Date = new Date(),
): string | null {
  const alwaysRequired: string[] = [
    "dateOfBirth",
    "yearsPlaying",
    "greekExperience",
    "internationalExperience",
  ];
  const req = version === 3 ? requiredFields(a) : alwaysRequired;

  for (const f of req) {
    const v = (a as Record<string, unknown>)[f];
    if (v === undefined || v === null || v === "") {
      return `Missing required questionnaire field: ${f}`;
    }
  }

  if (!GREEK_EXPERIENCES.includes(a.greekExperience as never)) {
    return "Invalid greek_experience";
  }
  if (!INTERNATIONAL_EXPERIENCES.includes(a.internationalExperience as never)) {
    return "Invalid international_experience";
  }

  const age = ageFromDob(a.dateOfBirth!, now);
  if (age < MIN_AGE || age > MAX_AGE) {
    return `You must be at least ${MIN_AGE} years old to participate`;
  }

  const years = Number(a.yearsPlaying);
  if (!Number.isFinite(years) || years < 0 || years > YEARS_PLAYING_MAX) {
    return "years_playing must be between 0 and 80";
  }

  if (
    a.internationalExperience === "junior_intl" &&
    Number(a.juniorCareerHighRanking) <= 0
  ) {
    return "junior_career_high_ranking must be a positive number";
  }
  if (
    a.internationalExperience === "us_college" &&
    !DIVISIONS.includes(normaliseCollegeDivision(a.usCollegeDivision) as Division)
  ) {
    return "us_college_division is not a recognised division";
  }

  if (version === 2) return null;

  if (!PLAY_FREQUENCIES.includes(a.playFrequency as never)) {
    return "Invalid play_frequency";
  }
  if (typeof a.tournamentsLast3y !== "boolean") {
    return "tournaments_last_3y must be a boolean";
  }
  if (a.tournamentsLast3y) {
    const n = Number(a.tournamentsPerYear);
    if (
      !Number.isInteger(n) || n < TOURNAMENTS_PER_YEAR_MIN ||
      n > TOURNAMENTS_PER_YEAR_MAX
    ) {
      return "tournaments_per_year must be between 1 and 100";
    }
    if (!TOURNAMENT_LEVELS.includes(a.tournamentLevel as never)) {
      return "Invalid tournament_level";
    }
  }
  if (
    isRecreationalCohort(a as V2Answers) &&
    !OTHER_SPORTS.includes(a.otherSport as never)
  ) {
    return "Invalid other_sport";
  }

  return null;
}

/**
 * Clears answers the routing did not ask for, so a stale client or a
 * hand-crafted body cannot write a value into a column the player never saw.
 * Mutates and returns `a`.
 */
export function pruneOffBranch<T extends Partial<V3Answers>>(a: T): T {
  if (a.internationalExperience !== "junior_intl") {
    a.juniorCareerHighRanking = null;
  }
  if (a.internationalExperience !== "professional_adult") {
    a.receivedAtpWtaPoint = null;
  }
  if (a.internationalExperience !== "us_college") a.usCollegeDivision = null;
  if (a.tournamentsLast3y !== true) {
    a.tournamentsPerYear = null;
    a.tournamentLevel = null;
  }
  if (!isRecreationalCohort(a as V2Answers)) a.otherSport = null;
  return a;
}

// ── v2 algorithm (frozen) ─────────────────────────────────────────────────────

/**
 * The questionnaire v2 seed algorithm, lifted verbatim from the original
 * `index.ts`. **Do not change it.** Its only job is to keep serving request
 * bodies from clients that have not picked up the v3 bundle yet — a cached web
 * tab or an un-updated mobile build. The golden tests in `seed_test.ts` pin it
 * so it cannot drift while v3 evolves around it.
 *
 * Ranking note: "ranked >300" in the original spec means career high ranking
 * NUMBER < 300, i.e. the player reached a position better than 300th.
 */
export function computeSeedEloV2(a: V2Answers, now: Date = new Date()): number {
  const age = ageFromDob(a.dateOfBirth, now);
  const { greekExperience, internationalExperience, yearsPlaying, otherSport } =
    a;

  // Priority 1: professional international
  if (internationalExperience === "professional_adult") {
    if (a.receivedAtpWtaPoint === true) return age <= 39 ? 10.0 : 9.0;
    return 9.0;
  }

  // Priority 2: junior international
  if (internationalExperience === "junior_intl") {
    const ranking = a.juniorCareerHighRanking ?? 9999;
    if (ranking < 300) return age <= 39 ? 8.5 : 8.0;
    return age <= 39 ? 8.0 : 7.5;
  }

  // Priority 3: national Greek competitive experience
  if (greekExperience === "national_top20") {
    if (age <= 30) return 8.5;
    if (age <= 45) return 8.0;
    if (age <= 55) return 7.5;
    return 7.0;
  }
  if (greekExperience === "national_20_200") {
    if (age <= 35) return 8.0;
    if (age <= 45) return 7.5;
    return 7.0;
  }
  if (greekExperience === "national_u200") return age <= 30 ? 7.5 : 7.0;

  // Priority 4: recreational path
  if (internationalExperience === "recreational_intl") return 6.5;
  if (internationalExperience === "us_college") {
    // v2 stored the display string; accept either spelling so a legacy body
    // still scores the way it did before migration 030 normalised the column.
    const d = normaliseCollegeDivision(a.usCollegeDivision);
    return d === "division_1" ? 7.0 : 6.5;
  }
  if (otherSport === "racket_sports") return 6.5;
  if (otherSport === "other_sports") return 6.0;

  if (yearsPlaying < 2) return 5.5;
  if (yearsPlaying <= 5) return 6.0;
  return 6.5;
}

// ── v3 algorithm ──────────────────────────────────────────────────────────────
//
// All tables are in integer hundredths. See the arithmetic note at the top.

/** Credential bases. A player holding two credentials takes the higher one. */
const GREEK_BASE: Record<string, number> = {
  national_top20: 850,
  national_20_200: 800,
  national_u200: 750,
};

const COLLEGE_BASE: Record<string, number> = {
  division_1: 800,
  division_2: 750,
  division_3: 700,
  naia: 700,
  njcaa: 700,
};

/** Physical decline only. Inactivity is measured by the tournament block. */
function ageAdjustment(age: number): number {
  if (age <= 39) return 0;
  if (age <= 49) return -20;
  if (age <= 59) return -50;
  if (age <= 69) return -80;
  return -110;
}

const FREQUENCY_A: Record<string, number> = {
  rarely: -30,
  monthly: -15,
  weekly: 0,
  multiple_weekly: 15,
};

const FREQUENCY_B_NO_TOURNAMENTS: Record<string, number> = {
  rarely: -50,
  monthly: -25,
  weekly: 0,
  multiple_weekly: 20,
};

const VOLUME_A = (n: number): number =>
  n <= 2 ? -30 : n <= 5 ? -10 : n <= 11 ? 10 : 20;

const VOLUME_B = (n: number): number =>
  n <= 2 ? 0 : n <= 5 ? 15 : n <= 11 ? 30 : 40;

const LEVEL_A: Record<string, number> = {
  amateur: -30,
  intermediate: -10,
  age_category: 10,
  master: 20,
  open: 40,
};

const LEVEL_B_BASE: Record<string, number> = {
  amateur: 630,
  intermediate: 660,
  age_category: 680,
  master: 700,
  open: 720,
};

const OTHER_SPORT_BONUS: Record<string, number> = {
  racket_sports: 20,
  other_sports: 10,
  none: 0,
};

function yearsAdjustmentA(years: number): number {
  if (years < 1) return -40;
  if (years <= 2) return -20;
  if (years <= 9) return 0;
  if (years <= 19) return 10;
  return 20;
}

function yearsAdjustmentNoTournaments(years: number): number {
  if (years < 1) return -60;
  if (years <= 2) return -40;
  if (years <= 9) return 0;
  if (years <= 19) return 15;
  return 25;
}

/** The credential base for a cohort-A player, in hundredths. */
export function credentialBase(a: V2Answers): number {
  let base = GREEK_BASE[a.greekExperience] ?? 0;

  switch (a.internationalExperience) {
    case "professional_adult":
      base = Math.max(base, a.receivedAtpWtaPoint === true ? 1000 : 900);
      break;
    case "junior_intl":
      base = Math.max(base, (a.juniorCareerHighRanking ?? 9999) < 300 ? 850 : 800);
      break;
    case "us_college": {
      const d = normaliseCollegeDivision(a.usCollegeDivision) ?? "division_3";
      base = Math.max(base, COLLEGE_BASE[d] ?? 700);
      break;
    }
  }

  return base;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

/** Hundredths → a rating with one decimal place, rounded half-up. */
function toRating(hundredths: number): number {
  const clamped = clamp(hundredths, MIN_ELO * 100, MAX_ELO * 100);
  return Math.round(clamped / 10) / 10;
}

function seedCredentialed(a: V3Answers, age: number): number {
  const base = credentialBase(a);
  let v = base + ageAdjustment(age);

  if (a.tournamentsLast3y) {
    v += VOLUME_A(Number(a.tournamentsPerYear));
    v += LEVEL_A[a.tournamentLevel!] ?? 0;
  } else {
    // Three years without a tournament is the strongest staleness signal we have.
    v -= 100;
  }

  v += FREQUENCY_A[a.playFrequency] ?? 0;

  // The lower bound stops a lapsed credential sinking below an active lesser
  // one; the upper bound stops activity alone promoting a player past the next
  // credential tier.
  return toRating(clamp(v, Math.max(600, base - 150), Math.min(1000, base + 30)));
}

/** Bonuses that apply to a recreational player on either sub-branch. */
function recreationalBonuses(a: V3Answers): number {
  let v = OTHER_SPORT_BONUS[a.otherSport ?? "none"] ?? 0;
  if (a.internationalExperience === "recreational_intl") v += 30;
  return v;
}

/**
 * Sub-branch B-i, in hundredths: a recreational player who has not entered a
 * tournament in three years. Longevity and how often they play carry more weight
 * here than on B-ii, because they are the only signals available.
 */
function recreationalInactive(a: V3Answers): number {
  const v = 600 +
    yearsAdjustmentNoTournaments(Number(a.yearsPlaying)) +
    (FREQUENCY_B_NO_TOURNAMENTS[a.playFrequency] ?? 0) +
    recreationalBonuses(a);
  return clamp(v, MIN_ELO * 100, NO_TOURNAMENT_CAP * 100);
}

function seedRecreational(a: V3Answers): number {
  const inactive = recreationalInactive(a);
  if (!a.tournamentsLast3y) return toRating(inactive);

  const years = Number(a.yearsPlaying);
  const volume = Number(a.tournamentsPerYear);
  const level = a.tournamentLevel!;

  let v = (LEVEL_B_BASE[level] ?? 630) +
    VOLUME_B(volume) +
    yearsAdjustmentA(years) +
    (FREQUENCY_A[a.playFrequency] ?? 0) +
    recreationalBonuses(a);

  // Cross-checks against implausible combinations. Both are level-independent on
  // purpose: capping only the upper rungs would let `intermediate` out-score
  // `age_category` at the same volume, breaking monotonicity in level.
  let cap = RECREATIONAL_CEILING * 100;
  if (years < 2) cap = Math.min(cap, 600);
  if (volume <= LOW_VOLUME_THRESHOLD) cap = Math.min(cap, LOW_VOLUME_CAP * 100);

  const active = clamp(v, MIN_ELO * 100, cap);

  // Entering tournaments must never score below not entering them. Taking the
  // max makes that structural rather than something the caps have to be
  // hand-tuned to avoid — the cross-check caps above are absolute, so without it
  // a beginner who competes could land under a beginner who does not.
  return toRating(Math.max(active, inactive));
}

/**
 * Questionnaire v3 seed rating on the [5.0, 10.0] scale, one decimal place.
 *
 * Two cohorts, documented in `docs/ELO_SYSTEM.md` §3:
 *   A — credentialed: a credential base, decayed by age (physical decline only)
 *       and by tournament inactivity, floored so a credential always counts.
 *   B — recreational: a base from the tournament ladder (or 6.0 for someone who
 *       has not entered one in three years), capped at 7.5.
 */
export function computeSeedEloV3(a: V3Answers, now: Date = new Date()): number {
  return isRecreationalCohort(a)
    ? seedRecreational(a)
    : seedCredentialed(a, ageFromDob(a.dateOfBirth, now));
}
