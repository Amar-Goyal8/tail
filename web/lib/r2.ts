import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// Cloudflare R2 is S3-compatible. Configure via env (see .env.example).
const accountId = process.env.R2_ACCOUNT_ID!;
const bucket = process.env.R2_BUCKET!;

// Public base URL for serving clips (R2 public dev URL or custom domain).
export const publicBase = process.env.R2_PUBLIC_BASE_URL?.replace(/\/$/, "") ?? "";

export const s3 = new S3Client({
  region: "auto",
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
});

export const keys = {
  video: (id: string) => `clips/${id}.mp4`,
  meta: (id: string) => `clips/${id}.json`,
};

// Public URL for a stored object (used in <video> + OG tags).
export const publicUrl = (key: string) => `${publicBase}/${key}`;

// Presigned PUT so the desktop app uploads the mp4 straight to R2.
export async function presignVideoUpload(id: string, contentType = "video/mp4") {
  const cmd = new PutObjectCommand({
    Bucket: bucket,
    Key: keys.video(id),
    ContentType: contentType,
  });
  return getSignedUrl(s3, cmd, { expiresIn: 60 * 10 }); // 10 min
}

export interface ClipMeta {
  id: string;
  title?: string;
  width: number;
  height: number;
  durationSec: number;
  createdAt: string; // ISO
}

export async function putMeta(meta: ClipMeta) {
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: keys.meta(meta.id),
      ContentType: "application/json",
      Body: JSON.stringify(meta),
    })
  );
}

export async function getMeta(id: string): Promise<ClipMeta | null> {
  try {
    const res = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: keys.meta(id) }));
    const text = await res.Body!.transformToString();
    return JSON.parse(text) as ClipMeta;
  } catch {
    return null;
  }
}
