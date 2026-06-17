import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
const service = process.env.SUPABASE_SERVICE_ROLE_KEY;

// Anonymous client — public reads (clip pages) under RLS.
export const supaAnon = () => createClient(url, anon, { auth: { persistSession: false } });

// Service-role client — bypasses RLS. Server-only (claim, view bumps, admin).
export const supaAdmin = (): SupabaseClient => {
  if (!service) throw new Error("SUPABASE_SERVICE_ROLE_KEY not set");
  return createClient(url, service, { auth: { persistSession: false } });
};

// Client acting AS a user — RLS enforced via their access token (JWT).
export const supaUser = (jwt: string) =>
  createClient(url, anon, {
    auth: { persistSession: false },
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });

// Validate a Bearer JWT -> auth user id (or null).
export async function userIdFromJWT(jwt: string | null): Promise<string | null> {
  if (!jwt) return null;
  const { data, error } = await supaAnon().auth.getUser(jwt);
  if (error || !data.user) return null;
  return data.user.id;
}

// Pull the raw Bearer token off a request.
export function bearer(req: Request): string | null {
  const h = req.headers.get("authorization") ?? "";
  const m = h.match(/^Bearer\s+(.+)$/i);
  return m?.[1]?.trim() ?? null;
}
