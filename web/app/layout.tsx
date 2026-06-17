import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Tail — clip & share your best gaming moments",
  description: "Clip the last 30 seconds of any game on macOS and share a link that plays instantly — even in Discord.",
  metadataBase: new URL("https://tailclips.com"),
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap"
          rel="stylesheet"
        />
      </head>
      <body style={{ margin: 0, background: "#08090A", fontFamily: "'Space Grotesk', system-ui, sans-serif" }}>
        {children}
      </body>
    </html>
  );
}
