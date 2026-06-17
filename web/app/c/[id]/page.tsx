import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { keys, publicUrl } from "@/lib/r2";
import { supaAnon } from "@/lib/supabase";
import { C, mono } from "@/lib/ui";
import { TailMark } from "@/app/logo";

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
  const title = clip.title || clip.game || "Tail clip";
  return (
    <main style={{ minHeight: "100vh", color: C.text,
                   background: `radial-gradient(120% 70% at 50% -10%, #101319, ${C.bg} 60%)`,
                   display: "flex", flexDirection: "column" }}>
      <nav style={{ maxWidth: 1000, width: "100%", margin: "0 auto", padding: "18px 22px",
                    display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <a href="/" style={{ display: "flex", alignItems: "center", gap: 10, textDecoration: "none", color: C.text }}>
          <TailMark size={22} />
          <span style={{ fontWeight: 700, letterSpacing: 2 }}>TAIL</span>
        </a>
        <a href="/" style={btn}>Get Tail — free</a>
      </nav>

      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center",
                    justifyContent: "center", padding: "10px 22px 40px", gap: 16 }}>
        <video src={videoUrl} controls autoPlay playsInline
          style={{ width: "min(1000px, 92vw)", maxHeight: "74vh", borderRadius: 14, background: "#000",
                   border: `1px solid ${C.stroke}`, boxShadow: "0 20px 70px -20px rgba(0,0,0,.8)" }} />
        <div style={{ width: "min(1000px, 92vw)", display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{title}</div>
            <div style={{ font: `400 12px ${mono}`, color: C.dim, marginTop: 4 }}>
              {clip.game ? `${clip.game.toUpperCase()} · ` : ""}{clip.width}×{clip.height} · {Math.round(clip.duration_sec)}S
            </div>
          </div>
        </div>
      </div>
    </main>
  );
}

const btn: React.CSSProperties = {
  padding: "9px 16px", borderRadius: 10, fontWeight: 600, fontSize: 13, textDecoration: "none",
  color: C.accentText, background: `linear-gradient(180deg, ${C.accentHi}, #B6E22F)`,
};
