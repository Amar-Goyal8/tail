import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Tail",
  description: "High-quality game clips, shared by link.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body style={{ margin: 0 }}>{children}</body>
    </html>
  );
}
