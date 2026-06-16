const features = [
  ["🎯", "Replay buffer", "Press ⌃⌥C to grab the last 30 seconds. Never hit record."],
  ["⚡", "High quality", "1440p120 / 1080p240, hardware-encoded. 4K with Pro."],
  ["🔗", "Share by link", "Auto-uploads, copies a link. No files to send."],
  ["💬", "Discord embed", "Links play inline in Discord — instant web player."],
  ["✂️", "Trim", "Cut the clip to the moment that matters before sharing."],
  ["📚", "Your library", "Every clip saved to your account, manage from the app."],
];

export default function Home() {
  return (
    <main style={{ minHeight: "100vh", background: "radial-gradient(1200px 600px at 50% -10%, #1a1330, #0b0b0e)",
                   color: "#eaeaf0", fontFamily: "system-ui, sans-serif" }}>
      <section style={{ maxWidth: 920, margin: "0 auto", padding: "96px 24px 40px", textAlign: "center" }}>
        <div style={{ fontSize: 64 }}>🎬</div>
        <h1 style={{ fontSize: 56, margin: "8px 0 0", letterSpacing: -2, fontWeight: 800 }}>Tail</h1>
        <p style={{ fontSize: 20, opacity: 0.8, maxWidth: 560, margin: "16px auto 0", lineHeight: 1.5 }}>
          High-quality game clips for macOS. Clip the last 30 seconds and share a
          link that plays instantly — even inline in Discord.
        </p>
        <div style={{ marginTop: 28, display: "flex", gap: 12, justifyContent: "center", flexWrap: "wrap" }}>
          <a href="#" style={btn(true)}>Download for macOS</a>
          <a href="/upgrade" style={btn(false)}>Tail Pro · 4K</a>
        </div>
      </section>

      <section style={{ maxWidth: 920, margin: "0 auto", padding: "24px 24px 96px",
                        display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(240px, 1fr))", gap: 16 }}>
        {features.map(([icon, title, body]) => (
          <div key={title} style={{ background: "rgba(255,255,255,.04)", border: "1px solid rgba(255,255,255,.08)",
                                     borderRadius: 14, padding: 20 }}>
            <div style={{ fontSize: 26 }}>{icon}</div>
            <h3 style={{ margin: "10px 0 6px", fontSize: 17 }}>{title}</h3>
            <p style={{ margin: 0, opacity: 0.7, fontSize: 14, lineHeight: 1.5 }}>{body}</p>
          </div>
        ))}
      </section>
    </main>
  );
}

function btn(primary: boolean): React.CSSProperties {
  return {
    padding: "12px 22px", borderRadius: 10, fontWeight: 600, textDecoration: "none",
    color: primary ? "#0b0b0e" : "#eaeaf0",
    background: primary ? "#eaeaf0" : "rgba(255,255,255,.08)",
    border: primary ? "none" : "1px solid rgba(255,255,255,.15)",
  };
}
