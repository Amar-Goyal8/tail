import { NextResponse } from "next/server";
import { setPlan, type Plan } from "@/lib/r2";

// Manual plan grant — protected by ADMIN_SECRET. For testing + comp accounts
// before Stripe is wired. POST { accountId, plan } with header x-admin-secret.
export async function POST(req: Request) {
  const secret = process.env.ADMIN_SECRET;
  if (!secret || req.headers.get("x-admin-secret") !== secret) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }
  const body = await req.json().catch(() => null);
  if (!body?.accountId) return NextResponse.json({ error: "missing accountId" }, { status: 400 });
  const plan: Plan = body.plan === "pro" ? "pro" : "free";
  const rec = await setPlan(body.accountId, plan);
  return NextResponse.json(rec);
}
