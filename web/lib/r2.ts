import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  ListObjectsV2Command,
  DeleteObjectCommand,
} from "@aws-sdk/client-s3";
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
  // Per-account index entry pointing at a clip (enables "my clips").
  userClip: (accountId: string, id: string) => `users/${accountId}/clips/${id}.json`,
  userPrefix: (accountId: string) => `users/${accountId}/clips/`,
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
  accountId?: string; // owner (for "my clips" + delete auth)
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

// ---- Accounts / plans ----

export type Plan = "free" | "pro";
export interface AccountRecord {
  accountId: string;
  plan: Plan;
  updatedAt: string;
}

const accountKey = (id: string) => `accounts/${id}.json`;

export async function getAccount(id: string): Promise<AccountRecord> {
  try {
    const r = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: accountKey(id) }));
    return JSON.parse(await r.Body!.transformToString()) as AccountRecord;
  } catch {
    return { accountId: id, plan: "free", updatedAt: new Date().toISOString() };
  }
}

export async function setPlan(id: string, plan: Plan): Promise<AccountRecord> {
  const rec: AccountRecord = { accountId: id, plan, updatedAt: new Date().toISOString() };
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: accountKey(id),
      ContentType: "application/json",
      Body: JSON.stringify(rec),
    })
  );
  return rec;
}

// Add a clip to an account's index (cheap pointer = the metadata itself).
export async function addUserClip(accountId: string, meta: ClipMeta) {
  await s3.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: keys.userClip(accountId, meta.id),
      ContentType: "application/json",
      Body: JSON.stringify(meta),
    })
  );
}

// List an account's clips, newest first.
export async function listUserClips(accountId: string, limit = 100): Promise<ClipMeta[]> {
  const res = await s3.send(
    new ListObjectsV2Command({ Bucket: bucket, Prefix: keys.userPrefix(accountId), MaxKeys: limit })
  );
  const objs = res.Contents ?? [];
  const metas = await Promise.all(
    objs.map(async (o) => {
      try {
        const r = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: o.Key! }));
        return JSON.parse(await r.Body!.transformToString()) as ClipMeta;
      } catch {
        return null;
      }
    })
  );
  return metas
    .filter((m): m is ClipMeta => !!m)
    .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1));
}

// Delete a clip (video + meta + user index) — only by its owner.
export async function deleteClip(id: string, accountId: string): Promise<boolean> {
  const meta = await getMeta(id);
  if (!meta || meta.accountId !== accountId) return false;
  await Promise.all([
    s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: keys.video(id) })),
    s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: keys.meta(id) })),
    s3.send(new DeleteObjectCommand({ Bucket: bucket, Key: keys.userClip(accountId, id) })),
  ]);
  return true;
}
