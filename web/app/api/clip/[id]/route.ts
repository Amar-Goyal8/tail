import { NextResponse } from "next/server";
import { getMeta } from "@/lib/r2";

// Public clip stats (view count). No auth — anyone with the id can read.
export async function GET(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const meta = await getMeta(id);
  if (!meta) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json({ views: meta.views ?? 0 });
}
