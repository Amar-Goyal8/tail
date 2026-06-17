import SwiftUI
import AppKit
import CoreText

// Tail design system — "tactical capture console". Near-black surfaces, a single
// signal-lime accent used surgically, Space Grotesk (UI) + JetBrains Mono (HUD).
enum Theme {
    // MARK: Colors
    static let bg        = Color(hex: 0x08090A)   // app base
    static let surface   = Color(hex: 0x0E1013)   // sidebar / panels
    static let card      = Color(hex: 0x141619)   // cards
    static let elevated  = Color(hex: 0x1A1D21)   // hovered / controls
    static let stroke    = Color.white.opacity(0.07)
    static let strokeHi  = Color.white.opacity(0.14)

    static let accent    = Color(hex: 0xC4F042)   // signal-lime
    static let accentHi  = Color(hex: 0xCFF55E)
    static let accentText = Color(hex: 0x0A0D04)  // text on lime
    static let primary   = accent                 // alias (active states)
    static let primaryHi = accentHi
    static let live      = Color(hex: 0xFF5F57)   // REC / destructive
    static let success   = accent                 // armed / active (lime)

    static let text      = Color(hex: 0xECEFEC)
    static let textDim   = Color(hex: 0x868C88)
    static let textFaint = Color(hex: 0x565B57)

    // Lime action gradient (Clip / primary).
    static let violetGrad = LinearGradient(colors: [Color(hex: 0xCFF55E), Color(hex: 0xB6E22F)],
                                           startPoint: .top, endPoint: .bottom)
    static let orangeGrad = violetGrad
    static let bgGrad = RadialGradient(
        colors: [Color(hex: 0x101319), Color(hex: 0x08090A)],
        center: .init(x: 0.5, y: -0.08), startRadius: 0, endRadius: 900)

    // MARK: Radii / spacing
    enum R { static let sm = 9.0, md = 11.0, lg = 14.0, xl = 16.0 }

    // MARK: Fonts (Space Grotesk UI, JetBrains Mono HUD — variable, registered).
    enum FontWeight { case regular, medium, semibold, bold }
    private static func w(_ fw: FontWeight) -> Font.Weight {
        switch fw { case .regular: .regular; case .medium: .medium; case .semibold: .semibold; case .bold: .bold }
    }
    static func ui(_ size: CGFloat, _ fw: FontWeight = .regular) -> Font {
        .custom("Space Grotesk", size: size).weight(w(fw))
    }
    static func display(_ size: CGFloat) -> Font {
        .custom("Space Grotesk", size: size).weight(.bold)
    }
    static func mono(_ size: CGFloat, _ fw: FontWeight = .medium) -> Font {
        .custom("JetBrains Mono", size: size).weight(w(fw))
    }

    static func registerFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("fonts"),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return }
        for f in files where f.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

// MARK: Reusable components

// action = lime gradient (dark text) · primary = lime · ghost = outline.
struct TailButtonStyle: ButtonStyle {
    enum Kind { case action, primary, ghost }
    var kind: Kind = .primary
    var full = false
    func makeBody(configuration: Configuration) -> some View {
        let onLime = kind == .action || kind == .primary
        return configuration.label
            .font(Theme.ui(13, .semibold))
            .foregroundStyle(onLime ? Theme.accentText : Theme.text)
            .frame(maxWidth: full ? .infinity : nil)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background {
                switch kind {
                case .action: Theme.violetGrad
                case .primary: Color(.sRGB, red: 0.77, green: 0.94, blue: 0.26)
                case .ghost: Color.white.opacity(0.03)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.R.md)
                .stroke(kind == .ghost ? Theme.strokeHi : .clear))
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.md))
            .shadow(color: onLime ? Theme.accent.opacity(0.4) : .clear, radius: 14, y: 5)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PanelModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: Theme.R.lg).stroke(Theme.stroke))
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.lg))
    }
}
extension View {
    func panel(_ padding: CGFloat = 16) -> some View { modifier(PanelModifier(padding: padding)) }
}

// Crosshair / reticle logo mark.
struct ReticleMark: View {
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(Theme.accent.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(Theme.accent.opacity(0.4)))
            Circle().stroke(Theme.accent, lineWidth: 1.5).frame(width: size * 0.4, height: size * 0.4)
            Rectangle().fill(Theme.accent.opacity(0.4)).frame(width: size * 0.75, height: 1.5)
            Rectangle().fill(Theme.accent.opacity(0.4)).frame(width: 1.5, height: size * 0.75)
        }
        .frame(width: size, height: size)
    }
}
