// seed-elo — Edge Function (Deno)
// Called once after the onboarding questionnaire.
// Computes a placeholder seed ELO from questionnaire answers,
// writes a questionnaire_responses row, updates profiles.elo_rating,
// and sets questionnaire_done = true.
//
// NOTE (Q-02): The ELO formula below is a placeholder linear mapping.
// Replace with the calibrated formula once Q-02 is resolved.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Placeholder seed ELO calculation ─────────────────────────────────────────
// Scale: 5.0 – 10.0, 1 decimal place.
// Range constrained to [5.0, 10.0] by the questionnaire_responses check constraint.
// NOTE (Q-02): Replace with calibrated formula once Q-02 is resolved.

function computeSeedElo(params: {
  playingFrequency: string;
  selfAssessedLevel: string;
  yearsPlaying: number;
  hasCompeted: boolean;
}): number {
  let score = 5.0;

  // Self-assessed level — biggest signal (+0.0 to +3.0)
  switch (params.selfAssessedLevel) {
    case "beginner":     score += 0.0; break;
    case "intermediate": score += 1.0; break;
    case "advanced":     score += 2.0; break;
    case "competitive":  score += 3.0; break;
  }

  // Playing frequency (+0.0 to +1.0)
  switch (params.playingFrequency) {
    case "monthly":         score += 0.3; break;
    case "weekly":          score += 0.7; break;
    case "multiple_weekly": score += 1.0; break;
  }

  // Years playing (+0.0 to +0.7)
  if (params.yearsPlaying >= 10) {
    score += 0.7;
  } else if (params.yearsPlaying >= 5) {
    score += 0.5;
  } else if (params.yearsPlaying >= 2) {
    score += 0.2;
  }

  // Tournament experience (+0.3)
  if (params.hasCompeted) {
    score += 0.3;
  }

  // Clamp to [5.0, 10.0] — stored at full precision; display layer rounds to 1dp
  return Math.min(10.0, Math.max(5.0, score));
}

// ── Handler ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Parse and validate request body
    const body = await req.json();
    const {
      playing_frequency: playingFrequency,
      self_assessed_level: selfAssessedLevel,
      years_playing: yearsPlaying,
      preferred_surface: preferredSurface,
      has_competed: hasCompeted,
    } = body;

    if (!playingFrequency || !selfAssessedLevel || yearsPlaying === undefined ||
        !preferredSurface || hasCompeted === undefined) {
      return new Response(
        JSON.stringify({ error: "Missing required questionnaire fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Build Supabase admin client (service role — bypasses RLS)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Get the calling user's ID from the JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Not authenticated" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );

    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const playerId = user.id;

    // Compute seed ELO
    const seedElo = computeSeedElo({
      playingFrequency,
      selfAssessedLevel,
      yearsPlaying: Number(yearsPlaying),
      hasCompeted: Boolean(hasCompeted),
    });

    // Write questionnaire_responses row (upsert in case of retry)
    const { error: insertError } = await supabase
      .from("questionnaire_responses")
      .upsert({
        player_id: playerId,
        playing_frequency: playingFrequency,
        self_assessed_level: selfAssessedLevel,
        years_playing: Number(yearsPlaying),
        preferred_surface: preferredSurface,
        has_competed: Boolean(hasCompeted),
        seed_elo: seedElo,
      }, { onConflict: "player_id" });

    if (insertError) {
      console.error("questionnaire_responses insert error:", insertError);
      return new Response(
        JSON.stringify({ error: insertError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Update profiles: set elo_rating and questionnaire_done
    const { error: profileError } = await supabase
      .from("profiles")
      .update({ elo_rating: seedElo, questionnaire_done: true })
      .eq("id", playerId);

    if (profileError) {
      console.error("profiles update error:", profileError);
      return new Response(
        JSON.stringify({ error: profileError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ seed_elo: seedElo }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("seed-elo error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
