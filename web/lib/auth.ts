// Minimal account identity: an opaque, unguessable account token sent as
// `Authorization: Bearer <token>`. The token IS the account id for now (the
// desktop app generates + persists it). Swap for real OAuth (Discord) later
// without changing the storage model — accountId stays the key.
export function accountFrom(req: Request): string | null {
  const h = req.headers.get("authorization") ?? "";
  const m = h.match(/^Bearer\s+(.+)$/i);
  const token = m?.[1]?.trim();
  if (!token || token.length < 16) return null; // reject obviously-bogus ids
  return token;
}
