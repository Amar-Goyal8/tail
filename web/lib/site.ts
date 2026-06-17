// Canonical origin for share links. Prefer SITE_URL (set in Vercel env, e.g.
// https://tailclips.com) so links never depend on which host hit the API —
// avoids leaking *.vercel.app or preview URLs into share links. Falls back to
// the request origin when unset (local dev / pre-domain).
export function siteOrigin(req: Request): string {
  const env = process.env.SITE_URL?.replace(/\/$/, "");
  if (env) return env;
  return new URL(req.url).origin;
}
