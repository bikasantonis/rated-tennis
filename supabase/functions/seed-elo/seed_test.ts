// Tests for the seed-ELO algorithm. Run with:
//   deno test supabase/functions/seed-elo/
// No permission flags are needed — `seed.ts` has no imports and no side effects.
//
// The `requiredFields` cases below mirror the routing cases in
// `test/models/questionnaire_flow_test.dart`. Change a routing rule in one place
// and the other test must change with it.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  ageFromDob,
  computeSeedEloV2,
  computeSeedEloV3,
  credentialBase,
  hasCredentials,
  isRecreationalCohort,
  MAX_ELO,
  MIN_ELO,
  NO_TOURNAMENT_CAP,
  normaliseCollegeDivision,
  pruneOffBranch,
  RECREATIONAL_CEILING,
  requiredFields,
  TOURNAMENT_LEVELS,
  validate,
  type V2Answers,
  type V3Answers,
} from "./seed.ts";

/** Fixed clock so every age-dependent expectation is deterministic. */
const NOW = new Date("2026-09-26T12:00:00Z");

/** Date of birth for a player who is exactly `age` on NOW. */
const dobForAge = (age: number) => `${2026 - age}-09-26`;

function v3(overrides: Partial<V3Answers> = {}): V3Answers {
  return {
    dateOfBirth: dobForAge(30),
    yearsPlaying: 8,
    playFrequency: "weekly",
    greekExperience: "recreational",
    internationalExperience: "none",
    tournamentsLast3y: false,
    otherSport: "none",
    ...overrides,
  };
}

const seed = (o: Partial<V3Answers> = {}) => computeSeedEloV3(v3(o), NOW);

// ── ageFromDob ────────────────────────────────────────────────────────────────

Deno.test("ageFromDob does not count an unreached birthday", () => {
  assertEquals(ageFromDob("1990-09-26", NOW), 36);
  assertEquals(ageFromDob("1990-09-27", NOW), 35);
  assertEquals(ageFromDob("1990-12-31", NOW), 35);
  assertEquals(ageFromDob("1990-01-01", NOW), 36);
});

// ── v2, frozen ────────────────────────────────────────────────────────────────

Deno.test("computeSeedEloV2 golden cases", () => {
  const v2 = (o: Partial<V2Answers>): V2Answers => ({
    dateOfBirth: dobForAge(30),
    yearsPlaying: 8,
    greekExperience: "recreational",
    internationalExperience: "none",
    otherSport: "none",
    ...o,
  });
  const s = (o: Partial<V2Answers>) => computeSeedEloV2(v2(o), NOW);

  // Priority 1 — professional
  assertEquals(
    s({ internationalExperience: "professional_adult", receivedAtpWtaPoint: true }),
    10.0,
  );
  assertEquals(
    s({
      internationalExperience: "professional_adult",
      receivedAtpWtaPoint: true,
      dateOfBirth: dobForAge(45),
    }),
    9.0,
  );
  assertEquals(
    s({ internationalExperience: "professional_adult", receivedAtpWtaPoint: false }),
    9.0,
  );

  // Priority 2 — junior international
  assertEquals(
    s({ internationalExperience: "junior_intl", juniorCareerHighRanking: 150 }),
    8.5,
  );
  assertEquals(
    s({
      internationalExperience: "junior_intl",
      juniorCareerHighRanking: 150,
      dateOfBirth: dobForAge(45),
    }),
    8.0,
  );
  assertEquals(
    s({ internationalExperience: "junior_intl", juniorCareerHighRanking: 900 }),
    8.0,
  );
  assertEquals(
    s({
      internationalExperience: "junior_intl",
      juniorCareerHighRanking: 900,
      dateOfBirth: dobForAge(45),
    }),
    7.5,
  );

  // Priority 3 — Greek national
  assertEquals(s({ greekExperience: "national_top20" }), 8.5);
  assertEquals(
    s({ greekExperience: "national_top20", dateOfBirth: dobForAge(40) }),
    8.0,
  );
  assertEquals(
    s({ greekExperience: "national_top20", dateOfBirth: dobForAge(50) }),
    7.5,
  );
  assertEquals(
    s({ greekExperience: "national_top20", dateOfBirth: dobForAge(60) }),
    7.0,
  );
  assertEquals(s({ greekExperience: "national_20_200" }), 8.0);
  assertEquals(
    s({ greekExperience: "national_20_200", dateOfBirth: dobForAge(40) }),
    7.5,
  );
  assertEquals(
    s({ greekExperience: "national_20_200", dateOfBirth: dobForAge(50) }),
    7.0,
  );
  assertEquals(s({ greekExperience: "national_u200" }), 7.5);
  assertEquals(
    s({ greekExperience: "national_u200", dateOfBirth: dobForAge(40) }),
    7.0,
  );

  // Priority 4 — recreational
  assertEquals(s({ internationalExperience: "recreational_intl" }), 6.5);
  assertEquals(
    s({ internationalExperience: "us_college", usCollegeDivision: "Division I" }),
    7.0,
  );
  assertEquals(
    s({ internationalExperience: "us_college", usCollegeDivision: "division_1" }),
    7.0,
  );
  assertEquals(
    s({ internationalExperience: "us_college", usCollegeDivision: "NAIA" }),
    6.5,
  );
  assertEquals(s({ otherSport: "racket_sports" }), 6.5);
  assertEquals(s({ otherSport: "other_sports" }), 6.0);
  assertEquals(s({ yearsPlaying: 1 }), 5.5);
  assertEquals(s({ yearsPlaying: 4 }), 6.0);
  assertEquals(s({ yearsPlaying: 20 }), 6.5);
});

// ── Cohorts ───────────────────────────────────────────────────────────────────

Deno.test("cohorts are exact complements", () => {
  for (
    const g of ["recreational", "national_u200", "national_20_200", "national_top20"]
  ) {
    for (
      const i of [
        "none",
        "recreational_intl",
        "junior_intl",
        "professional_adult",
        "us_college",
      ]
    ) {
      const a = { greekExperience: g, internationalExperience: i };
      assertEquals(isRecreationalCohort(a), !hasCredentials(a), `${g}/${i}`);
    }
  }
});

Deno.test("recreational + ITF Masters stays recreational; us_college does not", () => {
  assert(isRecreationalCohort({
    greekExperience: "recreational",
    internationalExperience: "recreational_intl",
  }));
  assert(hasCredentials({
    greekExperience: "recreational",
    internationalExperience: "us_college",
  }));
});

Deno.test("credentialBase takes the higher of two credentials", () => {
  // v2 discarded the Greek answer entirely for a junior international.
  assertEquals(
    credentialBase({
      dateOfBirth: dobForAge(30),
      yearsPlaying: 8,
      greekExperience: "national_top20",
      internationalExperience: "junior_intl",
      juniorCareerHighRanking: 900,
    }),
    850,
  );
});

// ── Cohort A, the §3.1 table ──────────────────────────────────────────────────

Deno.test("cohort A worked scenarios", () => {
  const pro = {
    internationalExperience: "professional_adult",
    receivedAtpWtaPoint: true,
    greekExperience: "national_top20",
  } as const;
  const active = { tournamentsLast3y: true } as const;

  // A1 — ex-pro, 28, 12+/yr master, 3+×wk → capped at the scale maximum
  assertEquals(
    seed({
      ...pro,
      ...active,
      dateOfBirth: dobForAge(28),
      tournamentsPerYear: 14,
      tournamentLevel: "master",
      playFrequency: "multiple_weekly",
    }),
    10.0,
  );

  // A2 / A3 — lapsed ex-pro, held up by the credential floor at both ages
  for (const age of [45, 72]) {
    assertEquals(
      seed({
        ...pro,
        dateOfBirth: dobForAge(age),
        tournamentsLast3y: false,
        playFrequency: "rarely",
      }),
      8.5,
      `age ${age}`,
    );
  }

  // A4 — pro without a point, 35, 3–5/yr intermediate
  assertEquals(
    seed({
      internationalExperience: "professional_adult",
      receivedAtpWtaPoint: false,
      greekExperience: "national_top20",
      ...active,
      dateOfBirth: dobForAge(35),
      tournamentsPerYear: 4,
      tournamentLevel: "intermediate",
    }),
    8.8,
  );

  // A5 — national top-20, 30, 6–11/yr age category
  assertEquals(
    seed({
      greekExperience: "national_top20",
      ...active,
      tournamentsPerYear: 8,
      tournamentLevel: "age_category",
    }),
    8.7,
  );

  // A6 vs A7 — same credential, same age, differing only on whether they still
  // compete. This 1.3 gap is the whole point of the release; v2 gave both 7.5.
  assertEquals(
    seed({
      greekExperience: "national_top20",
      dateOfBirth: dobForAge(52),
      tournamentsLast3y: false,
      playFrequency: "monthly",
    }),
    7.0,
  );
  assertEquals(
    seed({
      greekExperience: "national_top20",
      dateOfBirth: dobForAge(52),
      ...active,
      tournamentsPerYear: 8,
      tournamentLevel: "master",
    }),
    8.3,
  );

  // A8 — junior international, 41, low volume at amateur level. Also pins
  // half-up rounding: the raw value is exactly 7.55.
  assertEquals(
    seed({
      internationalExperience: "junior_intl",
      juniorCareerHighRanking: 150,
      dateOfBirth: dobForAge(41),
      ...active,
      tournamentsPerYear: 2,
      tournamentLevel: "amateur",
      playFrequency: "monthly",
    }),
    7.6,
  );

  // A9 — national u200, 26, stopped competing
  assertEquals(
    seed({ greekExperience: "national_u200", tournamentsLast3y: false, dateOfBirth: dobForAge(26) }),
    6.5,
  );

  // A10 — US college Division III, 33
  assertEquals(
    seed({
      internationalExperience: "us_college",
      usCollegeDivision: "division_3",
      dateOfBirth: dobForAge(33),
      ...active,
      tournamentsPerYear: 4,
      tournamentLevel: "intermediate",
    }),
    6.8,
  );

  // A12 — open draws, held at the base + 0.3 cap
  assertEquals(
    seed({
      greekExperience: "national_top20",
      ...active,
      tournamentsPerYear: 8,
      tournamentLevel: "open",
    }),
    8.8,
  );
});

// ── Cohort B, the §3.2 table ──────────────────────────────────────────────────

Deno.test("cohort B worked scenarios", () => {
  // B1 — 1 year, rarely, no tournaments
  assertEquals(seed({ yearsPlaying: 1, playFrequency: "rarely" }), 5.1);
  // B2 — 6 years, weekly, no tournaments
  assertEquals(seed({ yearsPlaying: 6 }), 6.0);
  // B2b — the softened long-standing weekly player
  assertEquals(seed({ yearsPlaying: 14 }), 6.2);
  // B3 — 25 years, 3+×wk, racket-sports background, still no tournaments
  assertEquals(
    seed({
      yearsPlaying: 25,
      playFrequency: "multiple_weekly",
      otherSport: "racket_sports",
    }),
    6.7,
  );

  const t = { tournamentsLast3y: true } as const;

  // B4 — amateur, 1–2/yr
  assertEquals(
    seed({ ...t, tournamentsPerYear: 2, tournamentLevel: "amateur", yearsPlaying: 4 }),
    6.3,
  );
  // B5 — intermediate, 6–11/yr, 12 years
  assertEquals(
    seed({
      ...t,
      tournamentsPerYear: 8,
      tournamentLevel: "intermediate",
      yearsPlaying: 12,
    }),
    7.0,
  );
  // B6 / B7 / B10 — all pinned at the 7.5 ceiling
  assertEquals(
    seed({
      ...t,
      tournamentsPerYear: 14,
      tournamentLevel: "age_category",
      yearsPlaying: 22,
      playFrequency: "multiple_weekly",
      otherSport: "racket_sports",
    }),
    7.5,
  );
  assertEquals(
    seed({
      ...t,
      tournamentsPerYear: 14,
      tournamentLevel: "master",
      yearsPlaying: 22,
      playFrequency: "multiple_weekly",
      otherSport: "racket_sports",
      internationalExperience: "recreational_intl",
    }),
    7.5,
  );
  assertEquals(
    seed({
      ...t,
      tournamentsPerYear: 8,
      tournamentLevel: "open",
      yearsPlaying: 15,
      playFrequency: "multiple_weekly",
    }),
    7.5,
  );
  // B8 — the low-volume cross-check cap
  assertEquals(
    seed({
      ...t,
      tournamentsPerYear: 2,
      tournamentLevel: "master",
      yearsPlaying: 3,
      playFrequency: "monthly",
    }),
    6.8,
  );
  // B9 — the short-experience cross-check cap
  assertEquals(
    seed({
      ...t,
      tournamentsPerYear: 14,
      tournamentLevel: "master",
      yearsPlaying: 1,
      playFrequency: "multiple_weekly",
    }),
    6.0,
  );
});

// ── Properties over the whole answer space ────────────────────────────────────

const FREQS = ["rarely", "monthly", "weekly", "multiple_weekly"];
const VOLUMES = [1, 2, 3, 5, 6, 11, 12, 40];
const AGES = [16, 30, 39, 40, 49, 50, 59, 60, 69, 70, 90];
const YEARS = [0, 1, 2, 3, 9, 10, 19, 20, 50];
const SPORTS = ["racket_sports", "other_sports", "none"];

/** Credentials in ascending base order, for the monotonicity property. */
const CREDENTIALS: Partial<V3Answers>[] = [
  { greekExperience: "recreational", internationalExperience: "us_college", usCollegeDivision: "njcaa" },
  { greekExperience: "recreational", internationalExperience: "us_college", usCollegeDivision: "division_3" },
  { greekExperience: "national_u200", internationalExperience: "none" },
  { greekExperience: "recreational", internationalExperience: "us_college", usCollegeDivision: "division_2" },
  { greekExperience: "national_20_200", internationalExperience: "none" },
  { greekExperience: "recreational", internationalExperience: "us_college", usCollegeDivision: "division_1" },
  { greekExperience: "national_top20", internationalExperience: "none" },
  { greekExperience: "recreational", internationalExperience: "professional_adult", receivedAtpWtaPoint: false },
  { greekExperience: "recreational", internationalExperience: "professional_adult", receivedAtpWtaPoint: true },
];

/** Every combination either cohort can produce. */
function* allAnswers(): Generator<V3Answers> {
  const cohorts: Partial<V3Answers>[] = [
    { greekExperience: "recreational", internationalExperience: "none" },
    { greekExperience: "recreational", internationalExperience: "recreational_intl" },
    ...CREDENTIALS,
  ];
  for (const c of cohorts) {
    for (const age of AGES) {
      for (const years of YEARS) {
        for (const freq of FREQS) {
          for (const sport of SPORTS) {
            const common = {
              ...c,
              dateOfBirth: dobForAge(age),
              yearsPlaying: years,
              playFrequency: freq,
              otherSport: sport,
            };
            yield v3({ ...common, tournamentsLast3y: false });
            for (const vol of VOLUMES) {
              for (const lvl of TOURNAMENT_LEVELS) {
                yield v3({
                  ...common,
                  tournamentsLast3y: true,
                  tournamentsPerYear: vol,
                  tournamentLevel: lvl,
                });
              }
            }
          }
        }
      }
    }
  }
}

Deno.test("P1 every seed is in range with one decimal place", () => {
  let n = 0;
  for (const a of allAnswers()) {
    const s = computeSeedEloV3(a, NOW);
    assert(s >= MIN_ELO && s <= MAX_ELO, `${s} out of range`);
    assertEquals(Math.round(s * 10), s * 10, `${s} has >1 decimal`);
    n++;
  }
  // Guard against the generator silently collapsing to a handful of cases.
  assert(n > 5000, `only ${n} combinations exercised`);
});

Deno.test("P2 monotone non-decreasing in tournament volume", () => {
  for (const a of allAnswers()) {
    if (!a.tournamentsLast3y) continue;
    let prev = -Infinity;
    for (const vol of VOLUMES) {
      const s = computeSeedEloV3({ ...a, tournamentsPerYear: vol }, NOW);
      assert(s >= prev, `volume ${vol} dropped to ${s} from ${prev}`);
      prev = s;
    }
  }
});

Deno.test("P3 monotone non-decreasing in tournament level", () => {
  for (const a of allAnswers()) {
    if (!a.tournamentsLast3y) continue;
    let prev = -Infinity;
    for (const lvl of TOURNAMENT_LEVELS) {
      const s = computeSeedEloV3({ ...a, tournamentLevel: lvl }, NOW);
      assert(s >= prev, `level ${lvl} dropped to ${s} from ${prev}`);
      prev = s;
    }
  }
});

Deno.test("P4 monotone non-increasing in age", () => {
  for (const a of allAnswers()) {
    let prev = Infinity;
    for (const age of AGES) {
      const s = computeSeedEloV3({ ...a, dateOfBirth: dobForAge(age) }, NOW);
      assert(s <= prev, `age ${age} rose to ${s} from ${prev}`);
      prev = s;
    }
  }
});

Deno.test("P5 monotone non-decreasing in play frequency", () => {
  for (const a of allAnswers()) {
    let prev = -Infinity;
    for (const f of FREQS) {
      const s = computeSeedEloV3({ ...a, playFrequency: f }, NOW);
      assert(s >= prev, `frequency ${f} dropped to ${s} from ${prev}`);
      prev = s;
    }
  }
});

Deno.test("P6 playing tournaments never scores below not playing them", () => {
  for (const a of allAnswers()) {
    if (!a.tournamentsLast3y) continue;
    const inactive = computeSeedEloV3({
      ...a,
      tournamentsLast3y: false,
      tournamentsPerYear: null,
      tournamentLevel: null,
    }, NOW);
    assert(
      computeSeedEloV3(a, NOW) >= inactive,
      `${a.tournamentLevel}/${a.tournamentsPerYear} scored under ${inactive}`,
    );
  }
});

Deno.test("P7 cohort B is capped at 7.5 and cohort A floored at 6.0", () => {
  for (const a of allAnswers()) {
    const s = computeSeedEloV3(a, NOW);
    if (isRecreationalCohort(a)) {
      assert(s <= RECREATIONAL_CEILING, `recreational seed ${s} above the ceiling`);
    } else {
      assert(s >= 6.0, `credentialed seed ${s} below the floor`);
    }
  }
});

Deno.test("P8 a stronger credential never seeds lower", () => {
  for (const age of AGES) {
    for (const freq of FREQS) {
      for (const lvl of TOURNAMENT_LEVELS) {
        for (const active of [false, true]) {
          let prev = -Infinity;
          for (const c of CREDENTIALS) {
            const s = computeSeedEloV3(
              v3({
                ...c,
                dateOfBirth: dobForAge(age),
                playFrequency: freq,
                tournamentsLast3y: active,
                tournamentsPerYear: active ? 8 : null,
                tournamentLevel: active ? lvl : null,
              }),
              NOW,
            );
            assert(s >= prev, `credential order broke at ${s} after ${prev}`);
            prev = s;
          }
        }
      }
    }
  }
});

Deno.test("P10 the no-tournament branch tops out at its cap", () => {
  const best = {
    yearsPlaying: 50,
    playFrequency: "multiple_weekly",
    otherSport: "racket_sports",
    tournamentsLast3y: false,
  } as const;

  // The strongest profile that never enters a tournament.
  assertEquals(seed(best), 6.7);
  // The cap only binds once the ITF Masters bonus is added on top.
  assertEquals(
    seed({ ...best, internationalExperience: "recreational_intl" }),
    NO_TOURNAMENT_CAP,
  );

  // A modest tournament player still clears the best non-competitor.
  assert(
    seed({
      ...best,
      tournamentsLast3y: true,
      tournamentsPerYear: 8,
      tournamentLevel: "intermediate",
    }) >= seed(best),
  );
});

Deno.test("P12 a beginner who competes is never penalised for it", () => {
  // The `years < 2` cross-check caps the tournament branch at 6.0, which on its
  // own could land under what the no-tournament branch gives the same player.
  // `seedRecreational` takes the max of the two, so this holds structurally.
  for (const years of [0, 1]) {
    for (const sport of SPORTS) {
      for (const intl of ["none", "recreational_intl"]) {
        for (const freq of FREQS) {
          const common = {
            yearsPlaying: years,
            otherSport: sport,
            internationalExperience: intl,
            playFrequency: freq,
          };
          const inactive = seed({ ...common, tournamentsLast3y: false });
          for (const lvl of TOURNAMENT_LEVELS) {
            assert(
              seed({
                ...common,
                tournamentsLast3y: true,
                tournamentsPerYear: 14,
                tournamentLevel: lvl,
              }) >= inactive,
              `${years}y ${sport} ${intl} ${freq} ${lvl}`,
            );
          }
        }
      }
    }
  }
});

Deno.test("P11 rounding is half-up at one decimal", () => {
  // A8's raw value is exactly 7.55 in hundredths; float arithmetic would have
  // produced 7.5 here.
  assertEquals(
    seed({
      internationalExperience: "junior_intl",
      juniorCareerHighRanking: 150,
      dateOfBirth: dobForAge(41),
      tournamentsLast3y: true,
      tournamentsPerYear: 2,
      tournamentLevel: "amateur",
      playFrequency: "monthly",
    }),
    7.6,
  );
  // 6.0 + 0.15 is 6.149999999999999 in binary floating point.
  assertEquals(seed({ yearsPlaying: 14 }), 6.2);
});

// ── Division normalisation ────────────────────────────────────────────────────

Deno.test("normaliseCollegeDivision maps v2 labels and passes slugs through", () => {
  assertEquals(normaliseCollegeDivision("Division I"), "division_1");
  assertEquals(normaliseCollegeDivision("Division II"), "division_2");
  assertEquals(normaliseCollegeDivision("Division III"), "division_3");
  assertEquals(normaliseCollegeDivision("NAIA"), "naia");
  assertEquals(normaliseCollegeDivision("NJCAA"), "njcaa");
  assertEquals(normaliseCollegeDivision("division_1"), "division_1");
  assertEquals(normaliseCollegeDivision(null), null);
  assertEquals(normaliseCollegeDivision(""), null);
});

// ── requiredFields / validate ─────────────────────────────────────────────────

Deno.test("requiredFields mirrors the Dart routing rules", () => {
  const base = [
    "dateOfBirth",
    "yearsPlaying",
    "playFrequency",
    "greekExperience",
    "internationalExperience",
    "tournamentsLast3y",
  ];

  // Credentialed, no tournaments — six fields, no otherSport.
  assertEquals(
    requiredFields({
      greekExperience: "national_top20",
      internationalExperience: "none",
      tournamentsLast3y: false,
    }),
    base,
  );

  // Recreational picks up otherSport; ITF Masters counts as recreational.
  for (const i of ["none", "recreational_intl"]) {
    assertEquals(
      requiredFields({
        greekExperience: "recreational",
        internationalExperience: i,
        tournamentsLast3y: false,
      }),
      [...base, "otherSport"],
    );
  }

  // us_college is credentialed, and pulls in its own sub-field.
  assertEquals(
    requiredFields({
      greekExperience: "recreational",
      internationalExperience: "us_college",
      tournamentsLast3y: false,
    }),
    [...base, "usCollegeDivision"],
  );

  // The tournament block appears only on a yes.
  assertEquals(
    requiredFields({
      greekExperience: "national_top20",
      internationalExperience: "none",
      tournamentsLast3y: true,
    }),
    [...base, "tournamentsPerYear", "tournamentLevel"],
  );

  // International sub-fields.
  assert(
    requiredFields({ internationalExperience: "junior_intl" }).includes(
      "juniorCareerHighRanking",
    ),
  );
  assert(
    requiredFields({ internationalExperience: "professional_adult" }).includes(
      "receivedAtpWtaPoint",
    ),
  );
});

Deno.test("validate enforces the age gate and the routed requirements", () => {
  assertEquals(validate(v3(), 3, NOW), null);

  assert(validate(v3({ dateOfBirth: dobForAge(15) }), 3, NOW)?.includes("16"));
  assertEquals(validate(v3({ dateOfBirth: dobForAge(16) }), 3, NOW), null);
  assertEquals(validate(v3({ dateOfBirth: dobForAge(90) }), 3, NOW), null);
  assert(validate(v3({ dateOfBirth: dobForAge(91) }), 3, NOW) !== null);

  // A routed-away field is not required...
  assertEquals(
    validate(
      v3({ greekExperience: "national_top20", otherSport: null }),
      3,
      NOW,
    ),
    null,
  );
  // ...but a routed-in one is.
  assert(validate(v3({ otherSport: null }), 3, NOW) !== null);
  assert(validate(v3({ tournamentsLast3y: true }), 3, NOW) !== null);
  assert(
    validate(
      v3({ tournamentsLast3y: true, tournamentsPerYear: 0, tournamentLevel: "amateur" }),
      3,
      NOW,
    ) !== null,
  );

  // A v2 body carries none of the v3 fields and must still pass.
  assertEquals(
    validate(
      {
        dateOfBirth: dobForAge(30),
        yearsPlaying: 8,
        greekExperience: "recreational",
        internationalExperience: "us_college",
        usCollegeDivision: "Division I",
      },
      2,
      NOW,
    ),
    null,
  );

  assert(validate(v3({ greekExperience: "wat" }), 3, NOW) !== null);
  assert(validate(v3({ yearsPlaying: 99 }), 3, NOW) !== null);
});

Deno.test("pruneOffBranch clears answers the routing did not ask for", () => {
  const a = pruneOffBranch(v3({
    greekExperience: "national_top20",
    otherSport: "racket_sports",
    tournamentsLast3y: false,
    tournamentsPerYear: 12,
    tournamentLevel: "master",
    juniorCareerHighRanking: 5,
    receivedAtpWtaPoint: true,
    usCollegeDivision: "division_1",
  }));

  assertEquals(a.otherSport, null);
  assertEquals(a.tournamentsPerYear, null);
  assertEquals(a.tournamentLevel, null);
  assertEquals(a.juniorCareerHighRanking, null);
  assertEquals(a.receivedAtpWtaPoint, null);
  assertEquals(a.usCollegeDivision, null);

  // It keeps the sub-field that does belong to the selected option.
  const keep = pruneOffBranch(v3({
    internationalExperience: "junior_intl",
    juniorCareerHighRanking: 120,
  }));
  assertEquals(keep.juniorCareerHighRanking, 120);
  assertEquals(keep.otherSport, null); // junior_intl is credentialed
});
