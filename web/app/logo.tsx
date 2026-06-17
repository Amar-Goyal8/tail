// Tail comet mark — arrow head + two trailing motion bars.
export function TailMark({ size = 34, color = "#C4F042" }: { size?: number; color?: string }) {
  return (
    <svg viewBox="0 0 220 220" width={size} height={size} style={{ display: "block" }}>
      <path d="M40 86 l24 0 l-7 48 l-24 0 Z" fill={color} opacity="0.2" />
      <path d="M74 80 l26 0 l-9 60 l-26 0 Z" fill={color} opacity="0.45" />
      <path d="M112 73 C150 86 168 102 178 110 C168 118 150 134 112 147 Z" fill={color} />
    </svg>
  );
}
