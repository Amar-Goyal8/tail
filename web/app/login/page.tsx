"use client";
import { useState } from "react";
import { browserClient } from "@/lib/supabase-browser";
import { C, mono } from "@/lib/ui";
import { TailMark } from "@/app/logo";

export default function Login() {
  const supabase = browserClient();
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);

  const redirectTo = typeof window !== "undefined"
    ? `${window.location.origin}/auth/callback?next=/library` : undefined;

  const oauth = (provider: "discord" | "google") =>
    supabase.auth.signInWithOAuth({ provider, options: { redirectTo } });

  const magic = async () => {
    await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: redirectTo } });
    setSent(true);
  };

  return (
    <main style={{ minHeight: "100vh", color: C.text, display: "flex", alignItems: "center", justifyContent: "center",
                   background: `radial-gradient(120% 70% at 50% -10%, #101319, ${C.bg} 60%)` }}>
      <div style={{ width: 320, display: "flex", flexDirection: "column", gap: 14, alignItems: "center" }}>
        <TailMark size={52} />
        <div style={{ fontWeight: 700, fontSize: 26, letterSpacing: 4 }}>TAIL</div>
        <div style={{ color: C.dim, fontSize: 13, textAlign: "center" }}>Sign in to view your clips.</div>
        <button onClick={() => oauth("discord")} style={primary}>Continue with Discord</button>
        <button onClick={() => oauth("google")} style={primary}>Continue with Google</button>
        <div style={{ font: `500 10px ${mono}`, color: C.faint, margin: "2px 0" }}>OR</div>
        {sent ? (
          <div style={{ color: C.accent, fontSize: 13 }}>Check your email for the link.</div>
        ) : (
          <>
            <input placeholder="you@email.com" value={email} onChange={(e) => setEmail(e.target.value)}
              style={{ width: "100%", padding: 11, borderRadius: 9, background: C.card, color: C.text,
                       border: `1px solid ${C.stroke}`, fontSize: 13 }} />
            <button onClick={magic} disabled={!email} style={ghost}>Email me a magic link</button>
          </>
        )}
      </div>
    </main>
  );
}

const primary: React.CSSProperties = {
  width: "100%", padding: 12, borderRadius: 11, border: "none", cursor: "pointer", fontWeight: 600, fontSize: 14,
  color: C.accentText, background: `linear-gradient(180deg, ${C.accentHi}, #B6E22F)`,
};
const ghost: React.CSSProperties = {
  width: "100%", padding: 11, borderRadius: 10, cursor: "pointer", fontWeight: 500, fontSize: 13,
  color: C.text, background: "rgba(255,255,255,.03)", border: `1px solid ${C.strokeHi}`,
};
