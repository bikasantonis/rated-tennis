// seed-elo — Edge Function (Deno)
// Called once after the onboarding questionnaire.
// Computes the initial seed ELO from the player's tennis history,
// writes a questionnaire_responses row, updates profiles.elo_rating,
// and sets questionnaire_done = true.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ── ELO seed algorithm ────────────────────────────────────────────────────────
//
// Inputs
//   dateOfBirth            ISO date string (YYYY-MM-DD)
//   yearsPlaying           integer ≥ 0
//   greekExperience        'recreational' | 'national_u200' | 'national_20_200' | 'national_top20'
//   internationalExperience 'none' | 'recreational_intl' | 'junior_intl' | 'professional_adult' | 'us_college'
//   juniorCareerHighRanking integer > 0  (required when internationalExperience == 'junior_intl')
//   receivedAtpWtaPoint    boolean       (required when internationalExperience == 'professional_adult')
//   usCollegeDivision      string        (required when internationalExperience == 'us_college')
//   otherSport             'racket_sports' | 'other_sports' | 'none' | null
//                          (only supplied when greekExperience == 'recreational')
//
// Ranking note
//   "ranked >300"          in the spec means career high ranking NUMBER < 300
//                          (i.e. the player achieved a position better than 300th)
//   "ranked 300 or lower"  means career high ranking NUMBER ≥ 300
//                          (i.e. the player's best ranking was 300 or worse)
//
// Output: numeric rating on the [5.0, 10.0] scale (1 decimal place)

function ageFromDob(dateOfBirth: string): number {
  const today = new Date();
  const dob = new Date(dateOfBirth);
  let age = today.getFullYear() - dob.getFullYear();
  const m = today.getMonth() - dob.getMonth();
  if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) age--;
  return age;
}

function computeSeedElo(params: {
  dateOfBirth: string;
  yearsPlaying: number;
  greekExperience: string;
  internationalExperience: string;
  juniorCareerHighRanking?: number | null;
  receivedAtpWtaPoint?: boolean | null;
  usCollegeDivision?: string | null;
  otherSport?: string | null;
}): number {
  const age = ageFromDob(params.dateOfBirth);
  const {
    greekExperience,
    internationalExperience,
    yearsPlaying,
    otherSport,
  } = params;

  // ── Priority 1: Professional international ────────────────────────────────
  if (internationalExperience === "professional_adult") {
    if (params.receivedAtpWtaPoint === true) {
      return age <= 39 ? 10.0 : 9.0;
    }
    return 9.0; // competed professionally but never received a point
  }

  // ── Priority 2: Junior international ─────────────────────────────────────
  // ranking < 300  → "ranked >300" in spec  → more accomplished junior
  // ranking ≥ 300  → "ranked 300 or lower"  → less accomplished junior
  if (internationalExperience === "junior_intl") {
    const ranking = params.juniorCareerHighRanking ?? 9999;
    if (ranking < 300) {
      // top-300 junior: better historical ranking
      return age <= 39 ? 8.5 : 8.0;
    } else {
      // outside top 300
      return age <= 39 ? 8.0 : 7.5;
    }
  }

  // ── Priority 3: National Greek competitive experience ─────────────────────
  if (greekExperience === "national_top20") {
    if (age <= 30) return 8.5;
    if (age <= 45) return 8.0;
    if (age <= 55) return 7.5;
    return 7.0; // 56+
  }

  if (greekExperience === "national_20_200") {
    if (age <= 35) return 8.0;
    if (age <= 45) return 7.5;
    return 7.0; // 46+
  }

  if (greekExperience === "national_u200") {
    return age <= 30 ? 7.5 : 7.0;
  }

  // ── Priority 4: Recreational path ────────────────────────────────────────
  // (greekExperience == 'recreational')

  if (internationalExperience === "recreational_intl") return 6.5;

  if (internationalExperience === "us_college") {
    // Division I is competitive; other divisions treated as recreational-level
    return params.usCollegeDivision === "Division I" ? 7.0 : 6.5;
  }

  // Other competitive sport (Q5 — only present when greekExperience == 'recreational')
  if (otherSport === "racket_sports") return 6.5;
  if (otherSport === "other_sports") return 6.0;

  // Pure recreational — based purely on years playing
  if (yearsPlaying < 2) return 5.5;
  if (yearsPlaying <= 5) return 6.0;
  return 6.5; // > 5 years
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const {
      date_of_birth: dateOfBirth,
      years_playing: yearsPlaying,
      greek_experience: greekExperience,
      international_experience: internationalExperience,
      junior_career_high_ranking: juniorCareerHighRanking,
      received_atp_wta_point: receivedAtpWtaPoint,
      us_college_division: usCollegeDivision,
      other_sport: otherSport,
    } = body;

    if (
      !dateOfBirth ||
      yearsPlaying === undefined ||
      yearsPlaying === null ||
      !greekExperience ||
      !internationalExperience
    ) {
      return new Response(
        JSON.stringify({ error: "Missing required questionnaire fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Not authenticated" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));

    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const playerId = user.id;

    const seedElo = computeSeedElo({
      dateOfBirth,
      yearsPlaying: Number(yearsPlaying),
      greekExperience,
      internationalExperience,
      juniorCareerHighRanking: juniorCareerHighRanking != null
        ? Number(juniorCareerHighRanking)
        : null,
      receivedAtpWtaPoint: receivedAtpWtaPoint != null
        ? Boolean(receivedAtpWtaPoint)
        : null,
      usCollegeDivision: usCollegeDivision ?? null,
      otherSport: otherSport ?? null,
    });

    // Persist questionnaire responses (upsert for retry safety)
    const { error: insertError } = await supabase
      .from("questionnaire_responses")
      .upsert(
        {
          player_id: playerId,
          date_of_birth: dateOfBirth,
          years_playing: Number(yearsPlaying),
          greek_experience: greekExperience,
          international_experience: internationalExperience,
          junior_career_high_ranking: juniorCareerHighRanking ?? null,
          received_atp_wta_point: receivedAtpWtaPoint ?? null,
          us_college_division: usCollegeDivision ?? null,
          other_sport: otherSport ?? null,
          seed_elo: seedElo,
        },
        { onConflict: "player_id" },
      );

    if (insertError) {
      console.error("questionnaire_responses upsert error:", insertError);
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Update profile
    const { error: profileError } = await supabase
      .from("profiles")
      .update({ elo_rating: seedElo, questionnaire_done: true })
      .eq("id", playerId);

    if (profileError) {
      console.error("profiles update error:", profileError);
      return new Response(JSON.stringify({ error: profileError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ seed_elo: seedElo }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("seed-elo error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
