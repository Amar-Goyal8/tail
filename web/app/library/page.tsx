import { redirect } from "next/navigation";
import { serverClient } from "@/lib/supabase-ssr";
import { keys, publicUrl } from "@/lib/r2";
import { C, mono } from "@/lib/ui";

export const dynamic = "force-dynamic";

export default async function Library() {
  const supabase = await serverClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: clips } = await supabase
    .from("clips")
    .select("id,title,game,width,height,duration_sec,views,created_at")
    .eq("owner", user.id)
    .order("created_at", { ascending: false });

  return (
    <main style={{ minHeight: "100vh", color: C.text,
                   background: `radial-gradient(120% 60% at 50% -10%, #101319, ${C.bg} 55%)` }}>
      <nav style={{ maxWidth: 1100, margin: "0 auto", padding: "18px 22px",
                    display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <span style={{ width: 22, height: 22, borderRadius: 6, background: "rgba(196,240,66,.14)",
                         border: `1px solid rgba(196,240,66,.4)`, display: "inline-block" }} />
          <span style={{ fontWeight: 700, letterSpacing: 2 }}>TAIL</span>
        </div>
        <span style={{ font: `400 12px ${mono}`, color: C.dim }}>{user.email}</span>
      </nav>

      <section style={{ maxWidth: 1100, margin: "0 auto", padding: "10px 22px 60px" }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: "10px 0 20px" }}>
          Your clips <span style={{ font: `600 13px ${mono}`, color: C.accent }}>{clips?.length ?? 0}</span>
        </h1>
        {!clips?.length ? (
          <div style={{ color: C.dim, padding: "60px 0", textAlign: "center" }}>
            No shared clips yet. Create a link in the Tail app and they’ll show up here.
          </div>
        ) : (
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: 18 }}>
            {clips.map((c) => (
              <a key={c.id} href={`/c/${c.id}`} style={{ textDecoration: "none", color: C.text,
                   background: C.card, border: `1px solid ${C.stroke}`, borderRadius: 14, overflow: "hidden" }}>
                <video src={publicUrl(keys.video(c.id))} muted playsInline preload="metadata"
                  style={{ width: "100%", aspectRatio: "16/9", objectFit: "cover", background: "#000", display: "block" }} />
                <div style={{ padding: "11px 13px" }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600 }}>{c.title || c.game || "Clip"}</div>
                  <div style={{ font: `400 11px ${mono}`, color: C.dim, marginTop: 3 }}>
                    {(c.game || "CLIP").toUpperCase()} · {c.views ?? 0} VIEWS
                  </div>
                </div>
              </a>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
