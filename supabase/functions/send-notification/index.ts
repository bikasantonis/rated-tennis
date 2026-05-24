// send-notification — Edge Function (Deno)
// Triggered by a DB webhook on INSERT into the notifications table.
// Reads the new row, looks up the recipient's OneSignal external_id,
// and sends a push notification via the OneSignal REST API.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")!;
const ONESIGNAL_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(req) });
  }

  try {
    // DB webhook sends the new row as { type, table, record, ... }
    const payload = await req.json();
    const record = payload.record ?? payload; // handle direct invocation too

    const recipientId: string = record.recipient_id;
    const title: string = record.title ?? "RATED";
    const body: string = record.body ?? "";
    const referenceType: string | null = record.reference_type ?? null;
    const referenceId: string | null = record.reference_id ?? null;

    if (!recipientId) {
      return new Response(
        JSON.stringify({ error: "recipient_id missing" }),
        { status: 400, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Verify recipient exists
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("id")
      .eq("id", recipientId)
      .maybeSingle();

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: "Recipient not found" }),
        { status: 404, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    // Build OneSignal notification payload
    const notification: Record<string, unknown> = {
      app_id: ONESIGNAL_APP_ID,
      // Target by external_id — this is the Supabase user UUID set via
      // NotificationService.identifyUser() in the Flutter app.
      include_aliases: {
        external_id: [recipientId],
      },
      target_channel: "push",
      headings: { en: title },
      contents: { en: body },
    };

    // Attach deep-link data so the app can route on tap
    if (referenceType && referenceId) {
      notification.data = {
        reference_type: referenceType,
        reference_id: referenceId,
      };
    }

    const osRes = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Key ${ONESIGNAL_API_KEY}`,
      },
      body: JSON.stringify(notification),
    });

    const osBody = await osRes.json();

    if (!osRes.ok) {
      console.error("OneSignal error:", osBody);
      return new Response(
        JSON.stringify({ error: "OneSignal delivery failed", detail: osBody }),
        { status: 502, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ ok: true, onesignal_id: osBody.id }),
      { status: 200, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("send-notification error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders(req), "Content-Type": "application/json" } },
    );
  }
});
