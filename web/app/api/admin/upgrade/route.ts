import { NextResponse } from "next/server";
import { supaAdmin } from "@/lib/supabase";

// Manual plan grant (ADMIN_SECRET) — testing + comps. POST { userId, plan }.
export async function POST(req: Request) {
  const secret = process.env.ADMIN_SECRET;
  if (!secret || req.headers.get("x-admin-secret") !== secret) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }
  const body = await req.json().catch(() => null);
  if (!body?.userId) return NextResponse.json({ error: "missing userId" }, { status: 400 });
  const plan = body.plan === "pro" ? "pro" : "free";
  const { error } = await supaAdmin().from("profiles").update({ plan }).eq("id", body.userId);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ userId: body.userId, plan });
}
