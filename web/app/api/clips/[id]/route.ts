import { NextResponse } from "next/server";
import { bearer, userIdFromJWT, supaUser } from "@/lib/supabase";
import { deleteVideo } from "@/lib/r2";

// Delete a clip (row via RLS owner-check, + R2 video).
export async function DELETE(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await ctx.params;

  const { error, count } = await supaUser(jwt).from("clips").delete({ count: "exact" }).eq("id", id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  if (!count) return NextResponse.json({ error: "not found" }, { status: 404 });
  await deleteVideo(id);
  return NextResponse.json({ ok: true });
}

// Update a clip (e.g. move to folder, rename). Owner-only via RLS.
export async function PATCH(req: Request, ctx: { params: Promise<{ id: string }> }) {
  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { id } = await ctx.params;
  const body = await req.json().catch(() => ({}));

  const patch: Record<string, unknown> = {};
  if ("folderId" in body) patch.folder_id = body.folderId; // null = unsorted
  if ("title" in body) patch.title = body.title;
  if (Object.keys(patch).length === 0) return NextResponse.json({ ok: true });

  const { error } = await supaUser(jwt).from("clips").update(patch).eq("id", id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ ok: true });
}
