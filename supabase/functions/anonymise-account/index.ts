// anonymise-account — Edge Function (Deno)
// GDPR Art. 17 "right to erasure".
// Called by the authenticated user who wants their account deleted.
// Steps:
//   1. Verify the JWT belongs to a real user.
//   2. Scrub all PII columns in `profiles` and set deleted_at = now().
//   3. Delete the Supabase Auth user (hard delete via admin API).
// The profiles row is kept (anonymised) so match history FK integrity is maintained.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

function jsonResponse(req: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse(req, { error: "Not authenticated" }, 401);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Identify the calling user from their JWT
    const { data: { user }, error: userError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (userError || !user) {
      return jsonResponse(req, { error: "Invalid token" }, 401);
    }

    const userId = user.id;

    // Scrub PII from profiles row — keep the row for FK integrity.
    // Location fields are cleared here to satisfy GDPR Art. 17 for location data.
    const { error: profileError } = await supabase
      .from("profiles")
      .update({
        display_name: "Deleted User",
        avatar_url: null,
        club_id: null,
        preferred_language: "en",
        is_public: false,
        deleted_at: new Date().toISOString(),
        // Clear location data (GDPR Art. 17 — right to erasure)
        location_consent: false,
        location_consent_at: null,
        home_city: null,
        home_lat: null,
        home_lng: null,
        notify_nearby_tournaments: false,
      })
      .eq("id", userId);

    if (profileError) {
      console.error("profile scrub error:", profileError);
      return jsonResponse(req, { error: profileError.message }, 500);
    }

    // Delete questionnaire responses — contains PII (date_of_birth, career history).
    // GDPR Art. 17: this data has no FK integrity purpose, so hard-delete is correct.
    const { error: questionnaireError } = await supabase
      .from("questionnaire_responses")
      .delete()
      .eq("player_id", userId);

    if (questionnaireError) {
      console.error("questionnaire delete error:", questionnaireError);
      return jsonResponse(req, { error: questionnaireError.message }, 500);
    }

    // Hard-delete the Supabase Auth user (removes login credentials / email)
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);
    if (deleteError) {
      console.error("auth delete error:", deleteError);
      return jsonResponse(req, { error: deleteError.message }, 500);
    }

    return jsonResponse(req, { ok: true });
  } catch (err) {
    console.error("anonymise-account error:", err);
    return jsonResponse(req, { error: "Internal server error" }, 500);
  }
});
