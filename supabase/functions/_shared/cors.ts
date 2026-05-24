// Shared CORS helper for all RATED Edge Functions.
//
// Strategy:
//   - No Origin header (native mobile, server-to-server): return "*" — CORS is
//     irrelevant here; native HTTP clients don't enforce it.
//   - Known Origin: echo it back so the browser accepts the response.
//   - Unknown browser Origin: return "" which causes the browser to block the
//     response, preventing cross-site credential abuse.
//
// ⚠️  BEFORE PRODUCTION LAUNCH: add the deployed web domain to ALLOWED_ORIGINS.
//     See docs/DEPLOYMENT_CHECKLIST.md → "Update CORS allowed origins".

const ALLOWED_ORIGINS = new Set([
  "http://localhost:3000", // Flutter web dev (--web-port=3000)
  "http://localhost:8080", // Alternative dev port
  // TODO(launch): uncomment and set the production web domain
  // "https://app.ratedtennis.gr",
]);

export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");

  let allowOrigin: string;
  if (origin === null) {
    // Non-browser client (native mobile app, pg_cron webhook, etc.)
    allowOrigin = "*";
  } else if (ALLOWED_ORIGINS.has(origin)) {
    allowOrigin = origin;
  } else {
    // Unknown browser origin — block the response
    allowOrigin = "";
  }

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };
}
