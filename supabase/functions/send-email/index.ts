// send-email — Edge Function (Deno)
// Triggered by a DB webhook on INSERT into the notifications table.
// Sends transactional email via Resend for organiser-request notification types.
//
// Required environment variables (set in Supabase Dashboard → Project Settings → Edge Functions):
//   RESEND_API_KEY        — from resend.com (free tier: 100 emails/day)
//   FROM_EMAIL            — e.g. "RATED <noreply@yourdomain.com>"
//   SUPABASE_URL          — set automatically by Supabase
//   SUPABASE_SERVICE_ROLE_KEY — set automatically by Supabase
//
// Webhook setup (Supabase Dashboard → Database → Webhooks):
//   Name:       send-email
//   Table:      notifications
//   Events:     INSERT
//   URL:        https://<project-ref>.supabase.co/functions/v1/send-email
//   HTTP method: POST

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") ?? "RATED <noreply@rated.app>";

// Only send email for these notification types.
// Add more types here as the product grows (e.g. 'match_submitted', 'tournament_starts').
const EMAIL_TYPES = new Set([
  "organizer_request_submitted",
  "organizer_request_approved",
  "organizer_request_denied",
]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const record = payload.record ?? payload;

    const notificationType: string = record.type ?? "";
    const recipientId: string = record.recipient_id ?? "";
    const title: string = record.title ?? "RATED";
    const body: string = record.body ?? "";

    // Skip types we don't email for.
    if (!EMAIL_TYPES.has(notificationType)) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "type not in email list" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!recipientId) {
      return new Response(
        JSON.stringify({ error: "recipient_id missing" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!RESEND_API_KEY) {
      console.warn("RESEND_API_KEY not set — skipping email delivery");
      return new Response(
        JSON.stringify({ skipped: true, reason: "RESEND_API_KEY not configured" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Look up the recipient's email address via the Supabase Admin API.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: userData, error: userError } =
      await supabase.auth.admin.getUserById(recipientId);

    if (userError || !userData?.user?.email) {
      console.error("Could not fetch recipient email:", userError);
      return new Response(
        JSON.stringify({ error: "Recipient email not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const toEmail = userData.user.email;
    const htmlBody = buildEmailHtml(title, body, notificationType);

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [toEmail],
        subject: title,
        html: htmlBody,
      }),
    });

    const resendBody = await resendRes.json();

    if (!resendRes.ok) {
      console.error("Resend error:", resendBody);
      return new Response(
        JSON.stringify({ error: "Email delivery failed", detail: resendBody }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ ok: true, resend_id: resendBody.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("send-email error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

function buildEmailHtml(title: string, body: string, type: string): string {
  const accentColor = "#3B82F6"; // matches AppColors.primary blue

  const ctaMap: Record<string, { label: string; path: string }> = {
    organizer_request_submitted: {
      label: "Review Request",
      path: "/admin/disputes",
    },
    organizer_request_approved: {
      label: "Go to Settings",
      path: "/settings",
    },
    organizer_request_denied: {
      label: "Go to Settings",
      path: "/settings",
    },
  };
  const cta = ctaMap[type];

  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
</head>
<body style="margin:0;padding:0;background:#f4f4f5;font-family:system-ui,-apple-system,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table width="100%" style="max-width:480px;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,0.08);">
          <!-- Header -->
          <tr>
            <td style="background:${accentColor};padding:24px 32px;">
              <p style="margin:0;font-size:22px;font-weight:700;color:#ffffff;letter-spacing:-0.5px;">RATED</p>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td style="padding:32px;">
              <h1 style="margin:0 0 12px;font-size:18px;font-weight:600;color:#111827;">${escapeHtml(title)}</h1>
              <p style="margin:0 0 24px;font-size:15px;color:#374151;line-height:1.6;">${escapeHtml(body)}</p>
              ${cta
                ? `<a href="${escapeHtml(cta.path)}"
                     style="display:inline-block;padding:12px 24px;background:${accentColor};color:#ffffff;
                            text-decoration:none;border-radius:8px;font-size:14px;font-weight:600;">
                     ${escapeHtml(cta.label)}
                   </a>`
                : ""}
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding:16px 32px;border-top:1px solid #f3f4f6;">
              <p style="margin:0;font-size:12px;color:#9ca3af;">
                You received this email because you have an account on RATED.<br/>
                If this was unexpected, you can ignore this message.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
