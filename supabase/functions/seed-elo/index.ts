// seed-elo — Edge Function (Deno)
// Called after the onboarding questionnaire, and again on every retake.
//
// Computes the seed rating, upserts the questionnaire_responses row, and marks
// the profile done at the current questionnaire version. The rating itself is
// only written for a player with no confirmed matches — see the guard below.
//
// The algorithm lives in ./seed.ts so it can be unit-tested (`deno test
// supabase/functions/seed-elo/`). This file is transport, validation and
// persistence only.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  computeSeedEloV2,
  computeSeedEloV3,
  normaliseCollegeDivision,
  pruneOffBranch,
  validate,
  type V3Answers,
} from "./seed.ts";

/** Must match `kQuestionnaireVersion` in questionnaire_flow.dart. */
const CURRENT_VERSION = 3;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), {
      status,
      headers: { ...corsHeaders(req), "Content-Type": "application/json" },
    });

  try {
    const body = await req.json();

    // Version dispatch is explicit rather than sniffed: a body without
    // `questionnaire_version` comes from a client that has not picked up the v3
    // bundle. Cloudflare Pages serves a hashed bundle so open tabs keep running
    // old JS, and the mobile builds are not force-updatable, so this path has to
    // keep working for a while. See docs/TODO.md for its removal.
    const version: 2 | 3 = body.questionnaire_version === CURRENT_VERSION ? 3 : 2;

    const answers: Partial<V3Answers> = {
      dateOfBirth: body.date_of_birth,
      yearsPlaying: body.years_playing != null
        ? Number(body.years_playing)
        : undefined,
      playFrequency: body.play_frequency,
      greekExperience: body.greek_experience,
      internationalExperience: body.international_experience,
      juniorCareerHighRanking: body.junior_career_high_ranking != null
        ? Number(body.junior_career_high_ranking)
        : null,
      receivedAtpWtaPoint: body.received_atp_wta_point != null
        ? Boolean(body.received_atp_wta_point)
        : null,
      // Unconditional, for both versions: a v2 client still posts the display
      // string, which would now violate qr_us_college_division_check.
      usCollegeDivision: normaliseCollegeDivision(body.us_college_division),
      tournamentsLast3y: typeof body.tournaments_last_3y === "boolean"
        ? body.tournaments_last_3y
        : undefined,
      tournamentsPerYear: body.tournaments_per_year != null
        ? Number(body.tournaments_per_year)
        : null,
      tournamentLevel: body.tournament_level,
      otherSport: body.other_sport,
    };

    const invalid = validate(answers, version);
    if (invalid) return json({ error: invalid }, 400);

    // Clear anything the routing did not ask for, so a stale or hand-crafted
    // body cannot land a value in a column the player never saw — and so a
    // retaker who changed cohort does not keep their old branch's answers.
    pruneOffBranch(answers);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authenticated" }, 401);

    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (userError || !user) return json({ error: "Invalid token" }, 401);

    const playerId = user.id;

    const seedElo = version === 3
      ? computeSeedEloV3(answers as V3Answers)
      : computeSeedEloV2(answers as V3Answers);

    // ── Persist the answers (upsert keeps retries and retakes idempotent) ─────
    const { error: insertError } = await supabase
      .from("questionnaire_responses")
      .upsert(
        {
          player_id: playerId,
          date_of_birth: answers.dateOfBirth,
          years_playing: answers.yearsPlaying,
          play_frequency: answers.playFrequency ?? null,
          greek_experience: answers.greekExperience,
          international_experience: answers.internationalExperience,
          junior_career_high_ranking: answers.juniorCareerHighRanking ?? null,
          received_atp_wta_point: answers.receivedAtpWtaPoint ?? null,
          us_college_division: answers.usCollegeDivision ?? null,
          tournaments_last_3y: answers.tournamentsLast3y ?? null,
          tournaments_per_year: answers.tournamentsPerYear ?? null,
          tournament_level: answers.tournamentLevel ?? null,
          other_sport: answers.otherSport ?? null,
          seed_elo: seedElo,
        },
        { onConflict: "player_id" },
      );

    if (insertError) {
      console.error("questionnaire_responses upsert error:", insertError);
      return json({ error: insertError.message }, 500);
    }

    // ── Mark the questionnaire done at this version ───────────────────────────
    const { error: profileError } = await supabase
      .from("profiles")
      .update({ questionnaire_done: true, questionnaire_version: version })
      .eq("id", playerId);

    if (profileError) {
      console.error("profiles update error:", profileError);
      return json({ error: profileError.message }, 500);
    }

    // ── Apply the rating, but never over a match-earned one ───────────────────
    // Filtering on matches_played = 0 instead of reading it first closes the
    // read-then-write race and doubles as the "did it apply" signal.
    // matches_played is maintained by trg_match_counters (028) over
    // status in ('confirmed','overridden') — i.e. exactly settled matches.
    const { data: applied, error: eloError } = await supabase
      .from("profiles")
      .update({ elo_rating: seedElo })
      .eq("id", playerId)
      .eq("matches_played", 0)
      .select("id");

    if (eloError) {
      console.error("elo_rating update error:", eloError);
      return json({ error: eloError.message }, 500);
    }

    const ratingApplied = (applied?.length ?? 0) > 0;

    // The client explains the outcome to the player, so it needs the live
    // rating whenever the seed was not the thing that took effect.
    let currentElo = seedElo;
    let matchesPlayed = 0;
    if (!ratingApplied) {
      const { data: p } = await supabase
        .from("profiles")
        .select("elo_rating, matches_played")
        .eq("id", playerId)
        .maybeSingle();
      currentElo = Number(p?.elo_rating ?? seedElo);
      matchesPlayed = Number(p?.matches_played ?? 0);
    }

    return json({
      seed_elo: seedElo,
      rating_applied: ratingApplied,
      current_elo: currentElo,
      matches_played: matchesPlayed,
      questionnaire_version: version,
    });
  } catch (err) {
    console.error("seed-elo error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});
