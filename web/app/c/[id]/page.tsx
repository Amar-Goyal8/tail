import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { getMeta, keys, publicUrl, bumpViews } from "@/lib/r2";

type Props = { params: Promise<{ id: string }> };

// Open Graph / Twitter player tags -> Discord renders an inline video embed.
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const meta = await getMeta(id);
  if (!meta) return { title: "Clip not found — Tail" };

  const videoUrl = publicUrl(keys.video(id));
  const title = meta.title || "Tail clip";
  const w = meta.width || 1280;
  const h = meta.height || 720;

  return {
    title: `${title} — Tail`,
    openGraph: {
      title,
      type: "video.other",
      videos: [{ url: videoUrl, secureUrl: videoUrl, type: "video/mp4", width: w, height: h }],
    },
    twitter: {
      card: "player",
      title,
      players: [{ playerUrl: videoUrl, streamUrl: videoUrl, width: w, height: h }],
    },
    other: {
      "og:video:width": String(w),
      "og:video:height": String(h),
    },
  };
}

export default async function ClipPage({ params }: Props) {
  const { id } = await params;
  const meta = await getMeta(id);
  if (!meta) notFound();
  bumpViews(id).catch(() => {}); // fire-and-forget view count

  const videoUrl = publicUrl(keys.video(id));
  return (
    <main style={{ minHeight: "100vh", background: "#0b0b0e", color: "#eaeaf0",
                   display: "flex", flexDirection: "column", alignItems: "center",
                   justifyContent: "center", fontFamily: "system-ui, sans-serif", gap: 16 }}>
      <video
        src={videoUrl}
        controls
        autoPlay
        playsInline
        style={{ maxWidth: "92vw", maxHeight: "82vh", borderRadius: 10, background: "#000",
                 boxShadow: "0 8px 40px rgba(0,0,0,.6)" }}
      />
      <div style={{ opacity: 0.7, fontSize: 13 }}>
        {meta.title ? `${meta.title} · ` : ""}{meta.width}×{meta.height} · {Math.round(meta.durationSec)}s · Tail
      </div>
    </main>
  );
}
