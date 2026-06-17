import { NextResponse } from "next/server";
import { serverClient } from "@/lib/supabase-ssr";

// OAuth / magic-link callback: exchange the code for a session cookie, then go on.
export async function GET(req: Request) {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const next = url.searchParams.get("next") ?? "/library";
  if (code) {
    const supabase = await serverClient();
    await supabase.auth.exchangeCodeForSession(code);
  }
  return NextResponse.redirect(new URL(next, url.origin));
}
