import { NextResponse } from "next/server";
import { listUserClips, keys, publicUrl } from "@/lib/r2";
import { accountFrom } from "@/lib/auth";
import { siteOrigin } from "@/lib/site";

// List the authenticated account's clips ("my clips").
export async function GET(req: Request) {
  const accountId = accountFrom(req);
  if (!accountId) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const origin = siteOrigin(req);
  const clips = (await listUserClips(accountId)).map((m) => ({
    ...m,
    link: `${origin}/c/${m.id}`,
    videoUrl: publicUrl(keys.video(m.id)),
  }));
  return NextResponse.json({ clips });
}
