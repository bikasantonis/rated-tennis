// notify-nearby-tournament — Edge Function (Deno)
// Triggered by a DB webhook on tournaments UPDATE.
// When a tournament's status changes to 'registration_open' and it has a
// venue location, this function finds all players who:
//   - have location_consent = true
//   - have notify_nearby_tournaments = true
//   - are within their chosen nearby_radius_km of the tournament venue
// and bulk-inserts notification rows for each of them.
// The existing send-notification webhook then picks up each INSERT and
// delivers the push via OneSignal.
//
// GDPR note: this function runs server-side with the service role key and
// never returns personal location data to the client.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    const payload = await req.json();

    // DB webhook sends { type, table, record, old_record, ... }
    // We handle both UPDATE (status transition) and direct invocation.
    const record = payload.record ?? payload;
    const oldRecord = payload.old_record ?? null;

    const tournamentId: string | null = record?.id ?? null;
    const newStatus: string | null = record?.status ?? null;
    const oldStatus: string | null = oldRecord?.status ?? null;

    if (!tournamentId) {
      return new Response(
        JSON.stringify({ error: "tournament id missing" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Only proceed when the tournament has just become 'registration_open'.
    // This prevents re-notifying on other status changes.
    const isOpeningRegistration =
      newStatus === "registration_open" &&
      (oldStatus === null || oldStatus !== "registration_open");

    if (!isOpeningRegistration) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "status not transitioning to registration_open" }),
        { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Skip if the tournament has no location data (can't compute proximity).
    const venueLat = record?.venue_lat ?? null;
    const venueLng = record?.venue_lng ?? null;
    if (venueLat === null || venueLng === null) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "tournament has no venue location" }),
        { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Call the SQL function to get the list of users to notify.
    const { data: targets, error: targetsError } = await supabase
      .rpc("nearby_tournament_notify_targets", {
        p_tournament_id: tournamentId,
      });

    if (targetsError) {
      console.error("nearby_tournament_notify_targets error:", targetsError);
      return new Response(
        JSON.stringify({ error: "Failed to query notification targets", detail: targetsError }),
        { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    if (!targets || targets.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, notified: 0 }),
        { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    const tournamentName: string = record?.name ?? "A tournament";
    const city: string | null = record?.city ?? null;
    const locationText = city ? ` in ${city}` : " near you";

    // Build notification rows — one per target user.
    const notifications = (targets as Array<{ user_id: string }>).map((t) => ({
      recipient_id: t.user_id,
      type: "nearby_tournament",
      title: "New tournament near you",
      body: `${tournamentName}${locationText} is now open for registration.`,
      reference_id: tournamentId,
      reference_type: "tournament",
    }));

    // Bulk insert — each row triggers the send-notification webhook individually.
    // Insert in batches of 50 to avoid payload size limits.
    const batchSize = 50;
    let totalInserted = 0;
    for (let i = 0; i < notifications.length; i += batchSize) {
      const batch = notifications.slice(i, i + batchSize);
      const { error: insertError } = await supabase
        .from("notifications")
        .insert(batch);

      if (insertError) {
        console.error("Notification insert error:", insertError);
        // Continue with remaining batches rather than aborting entirely.
      } else {
        totalInserted += batch.length;
      }
    }

    return new Response(
      JSON.stringify({ ok: true, notified: totalInserted }),
      { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("notify-nearby-tournament error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
    );
  }
});
