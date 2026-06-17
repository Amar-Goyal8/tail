import { S3Client, PutObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// Cloudflare R2 (S3-compatible) — stores the clip VIDEO only. All metadata
// lives in Supabase Postgres now.
const accountId = process.env.R2_ACCOUNT_ID!;
const bucket = process.env.R2_BUCKET!;
export const publicBase = process.env.R2_PUBLIC_BASE_URL?.replace(/\/$/, "") ?? "";

export const s3 = new S3Client({
  region: "auto",
  endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID!,
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY!,
  },
});

export const keys = { video: (id: string) => `clips/${id}.mp4` };
export const publicUrl = (key: string) => `${publicBase}/${key}`;

export async function presignVideoUpload(id: string, contentType = "video/mp4") {
  const cmd = new PutObjectCommand({ Bucket: bucket, Key: keys.video(id), ContentType: contentType });
  return getSignedUrl(s3, cmd, { expiresIn: 60 * 10 });
}

export async function deleteVideo(id: string) {
  await s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: keys.video(id) }));
}
