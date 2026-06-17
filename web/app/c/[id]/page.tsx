import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { keys, publicUrl } from "@/lib/r2";
import { supaAnon } from "@/lib/supabase";

type Props = { params: Promise<{ id: string }> };

async function getClip(id: string) {
  const { data } = await supaAnon()
    .from("clips").select("title,game,width,height,duration_sec").eq("id", id).single();
  return data;
}

// Open Graph / Twitter player tags -> Discord renders an inline video embed.
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const clip = await getClip(id);
  if (!clip) return { title: "Clip not found — Tail" };

  const videoUrl = publicUrl(keys.video(id));
  const title = clip.title || clip.game || "Tail clip";
  const w = clip.width || 1280;
  const h = clip.height || 720;
  return {
    title: `${title} — Tail`,
    openGraph: {
      title, type: "video.other",
      videos: [{ url: videoUrl, secureUrl: videoUrl, type: "video/mp4", width: w, height: h }],
    },
    twitter: { card: "player", title, players: [{ playerUrl: videoUrl, streamUrl: videoUrl, width: w, height: h }] },
    other: { "og:video:width": String(w), "og:video:height": String(h) },
  };
}

export default async function ClipPage({ params }: Props) {
  const { id } = await params;
  const clip = await getClip(id);
  if (!clip) notFound();
  supaAnon().rpc("bump_views", { clip_id: id }).then(() => {}, () => {}); // fire-and-forget

  const videoUrl = publicUrl(keys.video(id));
  return (
    <main style={{ minHeight: "100vh", background: "#08090A", color: "#ECEFEC",
                   display: "flex", flexDirection: "column", alignItems: "center",
                   justifyContent: "center", fontFamily: "system-ui, sans-serif", gap: 16 }}>
      <video src={videoUrl} controls autoPlay playsInline
        style={{ maxWidth: "92vw", maxHeight: "82vh", borderRadius: 12, background: "#000",
                 boxShadow: "0 8px 40px rgba(0,0,0,.6)" }} />
      <div style={{ opacity: 0.6, fontSize: 13 }}>
        {clip.game ? `${clip.game} · ` : ""}{clip.width}×{clip.height} · {Math.round(clip.duration_sec)}s · Tail
      </div>
    </main>
  );
}
