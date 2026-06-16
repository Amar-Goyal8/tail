export default function Home() {
  return (
    <main style={{ minHeight: "100vh", background: "#0b0b0e", color: "#eaeaf0",
                   display: "flex", flexDirection: "column", alignItems: "center",
                   justifyContent: "center", fontFamily: "system-ui, sans-serif", gap: 12 }}>
      <h1 style={{ fontSize: 44, margin: 0, letterSpacing: -1 }}>🎬 Tail</h1>
      <p style={{ opacity: 0.7, maxWidth: 420, textAlign: "center" }}>
        High-quality game clips for macOS. Clip the last 30s, share by link —
        plays inline in Discord, no file needed.
      </p>
    </main>
  );
}
