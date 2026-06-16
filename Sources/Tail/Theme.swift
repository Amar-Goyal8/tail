import SwiftUI
import AppKit
import CoreText

// Tail design system — dark gaming aesthetic (retro-futurism energy).
// Indigo-violet core + orange action accent. Russo One display, Chakra Petch UI.
enum Theme {
    // MARK: Colors
    static let bg        = Color(hex: 0x0B0B12)   // app base
    static let surface   = Color(hex: 0x14141E)   // panels
    static let card      = Color(hex: 0x191926)   // cards
    static let elevated  = Color(hex: 0x21212F)   // hovered/raised
    static let stroke    = Color.white.opacity(0.08)
    static let strokeHi  = Color.white.opacity(0.16)

    static let primary   = Color(hex: 0x6D5DF6)   // indigo-violet
    static let primaryHi = Color(hex: 0x8B7CFF)
    static let accent    = Color(hex: 0xFF6A2B)   // orange action
    static let accentHi  = Color(hex: 0xFF8A4C)

    static let text      = Color(hex: 0xF4F4FA)
    static let textDim   = Color(hex: 0x9C9CB5)
    static let textFaint = Color(hex: 0x63637A)
    static let live      = Color(hex: 0xFF4D5E)
    static let success   = Color(hex: 0x2DD4A7)

    static let violetGrad = LinearGradient(colors: [Color(hex: 0x7B5CFF), Color(hex: 0xB14DFF)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
    static let orangeGrad = LinearGradient(colors: [accent, accentHi],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
    static let bgGrad = LinearGradient(
        colors: [Color(hex: 0x141026), Color(hex: 0x0B0B12)],
        startPoint: .top, endPoint: .bottom)

    // MARK: Radii / spacing
    enum R { static let sm = 8.0, md = 12.0, lg = 16.0, xl = 22.0 }

    // MARK: Fonts
    enum FontWeight { case regular, medium, semibold, bold }
    static func ui(_ size: CGFloat, _ w: FontWeight = .regular) -> Font {
        let name: String
        switch w {
        case .regular: name = "ChakraPetch-Regular"
        case .medium: name = "ChakraPetch-Medium"
        case .semibold: name = "ChakraPetch-SemiBold"
        case .bold: name = "ChakraPetch-Bold"
        }
        return .custom(name, size: size)
    }
    static func display(_ size: CGFloat) -> Font { .custom("RussoOne-Regular", size: size) }

    // Register bundled .ttf fonts (SwiftPM app has no Info.plist font path).
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

// Primary action button (orange gradient) / secondary (violet) / ghost.
struct TailButtonStyle: ButtonStyle {
    enum Kind { case action, primary, ghost }
    var kind: Kind = .primary
    var full = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(13, .semibold))
            .foregroundStyle(kind == .ghost ? Theme.text : .white)
            .frame(maxWidth: full ? .infinity : nil)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background {
                switch kind {
                case .action: Theme.orangeGrad
                case .primary: Theme.violetGrad
                case .ghost: Theme.elevated
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.R.md)
                .stroke(.white.opacity(kind == .ghost ? 0.1 : 0.18)))
            .clipShape(RoundedRectangle(cornerRadius: Theme.R.md))
            .shadow(color: (kind == .action ? Theme.accent : Theme.primary).opacity(kind == .ghost ? 0 : 0.35),
                    radius: 12, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// Card surface with stroke + soft shadow.
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
