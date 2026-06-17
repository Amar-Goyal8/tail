import { C, mono } from "@/lib/ui";

const features = [
  ["Instant replay buffer", "Press ⌃⌥C — the last 30 seconds are saved. No hitting record, ever."],
  ["High quality, low overhead", "1440p120 / 1080p240, hardware-encoded on Apple Silicon. 4K with Pro."],
  ["Share by link", "Every clip becomes a link that plays inline — in Discord, anywhere."],
  ["Your library, synced", "Sign in once. Your shared clips follow you to any device."],
  ["Trim & organize", "Cut to the moment, sort into folders, manage it all in-app."],
  ["Mic + game audio", "Capture desktop audio, your mic, or both — mixed into the clip."],
];

function Reticle({ size = 34 }: { size?: number }) {
  return (
    <div style={{ width: size, height: size, borderRadius: size * 0.28, position: "relative",
                  background: "rgba(196,240,66,.12)", border: "1px solid rgba(196,240,66,.4)",
                  display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div style={{ width: size * 0.4, height: size * 0.4, borderRadius: "50%", border: "1.5px solid " + C.accent }} />
      <div style={{ position: "absolute", width: size * 0.74, height: 1.5, background: "rgba(196,240,66,.4)" }} />
      <div style={{ position: "absolute", height: size * 0.74, width: 1.5, background: "rgba(196,240,66,.4)" }} />
    </div>
  );
}

export default function Home() {
  return (
    <main style={{ minHeight: "100vh", color: C.text,
                   background: `radial-gradient(130% 75% at 50% -8%, #101319 0%, ${C.bg} 60%)` }}>
      {/* nav */}
      <nav style={{ maxWidth: 1080, margin: "0 auto", padding: "22px 24px",
                    display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 11 }}>
          <Reticle />
          <span style={{ fontWeight: 700, fontSize: 19, letterSpacing: 3 }}>TAIL</span>
        </div>
        <a href="#download" style={btn(true)}>Download</a>
      </nav>

      {/* hero */}
      <section style={{ maxWidth: 820, margin: "0 auto", padding: "70px 24px 30px", textAlign: "center" }}>
        <div style={{ font: `500 11px ${mono}`, letterSpacing: ".22em", color: C.faint, textTransform: "uppercase" }}>
          Clip capture for macOS
        </div>
        <h1 style={{ fontSize: 60, lineHeight: 1.05, margin: "18px 0 0", fontWeight: 700, letterSpacing: -1.5 }}>
          Your best plays,<br /><span style={{ color: C.accent }}>one keystroke away.</span>
        </h1>
        <p style={{ fontSize: 19, color: C.dim, maxWidth: 520, margin: "20px auto 0", lineHeight: 1.5 }}>
          Tail records in the background. Press ⌃⌥C to grab the last 30 seconds and share a link
          that plays instantly — even inline in Discord.
        </p>
        <div id="download" style={{ marginTop: 30, display: "flex", gap: 12, justifyContent: "center", flexWrap: "wrap" }}>
          <a href="#" style={btn(true)}>↓ Download for macOS</a>
          <a href="/upgrade" style={btn(false)}>Tail Pro · 4K</a>
        </div>
        <div style={{ font: `500 11px ${mono}`, color: C.faint, marginTop: 14 }}>
          Apple Silicon · macOS 14+ · Free
        </div>
      </section>

      {/* features */}
      <section style={{ maxWidth: 1000, margin: "0 auto", padding: "40px 24px 90px",
                        display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: 16 }}>
        {features.map(([title, body]) => (
          <div key={title} style={{ background: C.card, border: `1px solid ${C.stroke}`, borderRadius: 14, padding: 22 }}>
            <div style={{ width: 8, height: 8, borderRadius: "50%", background: C.accent, boxShadow: `0 0 10px ${C.accent}` }} />
            <h3 style={{ margin: "14px 0 6px", fontSize: 17 }}>{title}</h3>
            <p style={{ margin: 0, color: C.dim, fontSize: 14, lineHeight: 1.55 }}>{body}</p>
          </div>
        ))}
      </section>

      <footer style={{ borderTop: `1px solid ${C.stroke}`, padding: "26px 24px", textAlign: "center",
                       font: `400 12px ${mono}`, color: C.faint }}>
        TAIL · tailclips.com · © 2026
      </footer>
    </main>
  );
}

function btn(primary: boolean): React.CSSProperties {
  return {
    padding: "12px 22px", borderRadius: 11, fontWeight: 600, fontSize: 14, textDecoration: "none",
    color: primary ? C.accentText : C.text,
    background: primary ? `linear-gradient(180deg, ${C.accentHi}, #B6E22F)` : "rgba(255,255,255,.04)",
    border: primary ? "none" : `1px solid ${C.strokeHi}`,
    boxShadow: primary ? "0 6px 20px -5px rgba(196,240,66,.5)" : "none",
  };
}
