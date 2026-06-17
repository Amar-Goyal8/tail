import { NextResponse } from "next/server";
import { bearer, userIdFromJWT, supaUser } from "@/lib/supabase";
import { siteOrigin } from "@/lib/site";

// After the mp4 is uploaded to R2, record the clip row (owner = signed-in user).
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  if (!body?.id) return NextResponse.json({ error: "missing id" }, { status: 400 });

  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { error } = await supaUser(jwt).from("clips").insert({
    id: body.id,
    owner: uid,
    title: body.title ?? null,
    game: body.game ?? null,
    width: Number(body.width) || 0,
    height: Number(body.height) || 0,
    duration_sec: Number(body.durationSec) || 0,
  });
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  return NextResponse.json({ id: body.id, link: `${siteOrigin(req)}/c/${body.id}` });
}
