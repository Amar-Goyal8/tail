import { NextResponse } from "next/server";
import { nanoid } from "nanoid";
import { presignVideoUpload, keys, publicUrl } from "@/lib/r2";

// Step 1 of upload: desktop app asks for a short id + presigned PUT URL.
// Then it PUTs the mp4 straight to R2, then calls /api/finalize.
export async function POST(req: Request) {
  const contentType = (await req.json().catch(() => ({})))?.contentType ?? "video/mp4";
  const id = nanoid(10); // short, URL-safe share id
  const uploadUrl = await presignVideoUpload(id, contentType);
  return NextResponse.json({
    id,
    uploadUrl,
    videoUrl: publicUrl(keys.video(id)),
  });
}
