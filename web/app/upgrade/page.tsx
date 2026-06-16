export default async function Upgrade({ searchParams }: { searchParams: Promise<{ status?: string }> }) {
  const { status } = await searchParams;
  const msg =
    status === "success" ? "🎉 You're Pro! 4K + higher bitrates unlocked. Back to the app."
    : status === "cancel" ? "Checkout canceled — no charge."
    : "Tail Pro unlocks 4K capture and higher bitrates.";
  return (
    <main style={{ minHeight: "100vh", background: "#0b0b0e", color: "#eaeaf0",
                   display: "flex", flexDirection: "column", alignItems: "center",
                   justifyContent: "center", fontFamily: "system-ui, sans-serif", gap: 12 }}>
      <h1 style={{ margin: 0 }}>Tail Pro</h1>
      <p style={{ opacity: 0.8 }}>{msg}</p>
    </main>
  );
}
