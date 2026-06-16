import { NextResponse } from "next/server";
import { deleteClip } from "@/lib/r2";
import { accountFrom } from "@/lib/auth";

// Delete a clip — only its owner (matching account token) may.
export async function DELETE(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const accountId = accountFrom(req);
  if (!accountId) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await ctx.params;
  const ok = await deleteClip(id, accountId);
  if (!ok) return NextResponse.json({ error: "not found or not owner" }, { status: 404 });
  return NextResponse.json({ ok: true });
}
