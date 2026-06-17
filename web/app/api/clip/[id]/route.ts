import { NextResponse } from "next/server";
import { supaAnon } from "@/lib/supabase";

// Public clip stats — increments + returns the view count. No auth.
export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const { data, error } = await supaAnon().rpc("bump_views", { clip_id: id });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ views: data ?? 0 });
}
