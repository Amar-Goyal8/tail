import { NextResponse } from "next/server";
import { putMeta, type ClipMeta } from "@/lib/r2";

// Step 2: after the mp4 is uploaded, store its metadata + return the share link.
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  if (!body?.id) return NextResponse.json({ error: "missing id" }, { status: 400 });

  const meta: ClipMeta = {
    id: body.id,
    title: body.title,
    width: Number(body.width) || 0,
    height: Number(body.height) || 0,
    durationSec: Number(body.durationSec) || 0,
    createdAt: new Date().toISOString(),
  };
  await putMeta(meta);

  const origin = new URL(req.url).origin;
  return NextResponse.json({ id: meta.id, link: `${origin}/c/${meta.id}` });
}
