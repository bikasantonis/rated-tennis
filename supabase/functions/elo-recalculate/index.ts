// elo-recalculate — Edge Function (Deno)
// Called by the Flutter app when a player confirms a match result.
// 1. Validates the caller is the loser (non-submitter) of the match.
// 2. Sets match status → 'confirmed' + confirmed_at = now().
// 3. Calls apply_elo_changes(match_id) to update both profiles and elo_history.
// Idempotent: apply_elo_changes is a no-op if history rows already exist.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    const { match_id: matchId } = await req.json();
    if (!matchId) {
      return new Response(
        JSON.stringify({ error: "match_id is required" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Not authenticated" }),
        { status: 401, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Identify the calling user
    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (userError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid token" }),
        { status: 401, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Fetch the match
    const { data: match, error: matchError } = await supabase
      .from("match_results")
      .select("id, submitter_id, winner_id, loser_id, status")
      .eq("id", matchId)
      .single();

    if (matchError || !match) {
      return new Response(
        JSON.stringify({ error: "Match not found" }),
        { status: 404, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Only allow confirmation if match is still pending
    if (match.status !== "pending") {
      return new Response(
        JSON.stringify({ error: `Match is already ${match.status}` }),
        { status: 409, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Only the non-submitting participant may confirm
    const isParticipant =
      match.winner_id === user.id || match.loser_id === user.id;
    const isSubmitter = match.submitter_id === user.id;

    if (!isParticipant || isSubmitter) {
      return new Response(
        JSON.stringify({ error: "Only the opponent may confirm this result" }),
        { status: 403, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Confirm the match
    const { error: updateError } = await supabase
      .from("match_results")
      .update({ status: "confirmed", confirmed_at: new Date().toISOString() })
      .eq("id", matchId);

    if (updateError) {
      console.error("match update error:", updateError);
      return new Response(
        JSON.stringify({ error: updateError.message }),
        { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Apply ELO changes via the DB function (idempotent)
    const { error: rpcError } = await supabase.rpc("apply_elo_changes", {
      p_match_id: matchId,
    });

    if (rpcError) {
      console.error("apply_elo_changes error:", rpcError);
      return new Response(
        JSON.stringify({ error: rpcError.message }),
        { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("elo-recalculate error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
    );
  }
});
