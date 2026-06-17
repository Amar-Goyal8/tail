import { NextResponse } from "next/server";
import { bearer, userIdFromJWT, supaUser } from "@/lib/supabase";

// Delete a folder (clips fall back to unsorted via ON DELETE SET NULL).
export async function DELETE(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await ctx.params;
  const { error } = await supaUser(jwt).from("folders").delete().eq("id", id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true });
}
