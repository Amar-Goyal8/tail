import { createBrowserClient } from "@supabase/ssr";

// Client-safe Supabase client (no next/headers import).
export function browserClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
