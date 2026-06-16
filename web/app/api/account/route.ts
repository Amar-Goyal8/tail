import { NextResponse } from "next/server";
import { getAccount } from "@/lib/r2";
import { accountFrom } from "@/lib/auth";

// Current account's plan (free | pro). Drives 4K gating in the desktop app.
export async function GET(req: Request) {
  const accountId = accountFrom(req);
  if (!accountId) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const acct = await getAccount(accountId);
  return NextResponse.json({ accountId, plan: acct.plan });
}
