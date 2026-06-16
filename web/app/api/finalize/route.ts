import { NextResponse } from "next/server";
import { putMeta, addUserClip, type ClipMeta } from "@/lib/r2";
import { accountFrom } from "@/lib/auth";

// Step 2: after the mp4 is uploaded, store metadata + return the share link.
// If an account token is present, also index the clip under that account.
export async function POST(req: Request) {
  const body = await req.json().catch(() => null);
  if (!body?.id) return NextResponse.json({ error: "missing id" }, { status: 400 });

  const accountId = accountFrom(req) ?? undefined;
  const meta: ClipMeta = {
    id: body.id,
    title: body.title,
    width: Number(body.width) || 0,
    height: Number(body.height) || 0,
    durationSec: Number(body.durationSec) || 0,
    createdAt: new Date().toISOString(),
    accountId,
  };
  await putMeta(meta);
  if (accountId) await addUserClip(accountId, meta);

  const origin = new URL(req.url).origin;
  return NextResponse.json({ id: meta.id, link: `${origin}/c/${meta.id}` });
}
