import AppKit
import SwiftUI

/// A palette resolved into the colours the app draws with. It is worked out
/// once per palette and accessibility setting, then cached: views only read
/// finished colours, never hex codes or contrast maths.
struct AppTheme {
    let palette: Palette
    /// Set when the Mac asks for more contrast.
    let highContrast: Bool
    /// Set when the Mac asks for less transparency: the glass turns solid.
    let reduceTransparency: Bool

    let tint: Color
    let text: Color
    let secondary: Color
    /// Fill for pills and quiet buttons, and its hovered state.
    let surface: Color
    let surfaceHover: Color
    /// Hairline edges.
    let stroke: Color
    /// The part of a ring or bar already used up.
    let track: Color
    /// Soft blooms behind the glass, if the palette has them.
    let blooms: [Color]?
    private let moods: [Mood: MoodColors]

    var id: String { palette.id }
    var name: String { palette.name }
    var isDark: Bool { palette.isDark }
    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var fontDesign: Font.Design { palette.fontDesign }
    var material: NSVisualEffectView.Material { palette.material }
    var grain: Double { reduceTransparency ? 0 : palette.grain }

    func colors(for phase: Phase) -> MoodColors { moods[Mood(phase)]! }

    func glassOpacity(_ surface: GlassSurface) -> Double {
        if reduceTransparency { return 1 }
        switch surface {
        case .window: return palette.tintOpacity
        case .floating: return max(palette.tintOpacity, GlassSurface.floatingMinimum)
        }
    }
}

/// Everything drawn in a phase's accent, ready to use.
struct MoodColors {
    /// The phase label and other accent text: at least 4.5:1.
    let text: Color
    /// Progress bars, dots and icons: at least 3:1.
    let shape: Color
    /// The ring: the palette's gradient, or its accent fading in.
    let ring: [Color]
    let ringIsGradient: Bool
    /// The soft light behind the dial.
    let glow: Color
    /// The Start/Pause button.
    let button: ButtonFill
    /// The colour the glass leans toward during breaks.
    let wash: Color?
}

/// A filled button's colours and a label colour that reads on all of them.
struct ButtonFill {
    let stops: [Color]
    let label: Color
}

extension AppTheme {
    @MainActor private static var cache: [String: AppTheme] = [:]

    /// The resolved theme for a palette and the Mac's accessibility settings.
    @MainActor static func resolve(_ palette: Palette, highContrast: Bool = false,
                                   reduceTransparency: Bool = false) -> AppTheme {
        let key = "\(palette.id)|\(highContrast)|\(reduceTransparency)"
        if let hit = cache[key] { return hit }
        let theme = AppTheme(palette: palette, highContrast: highContrast, reduceTransparency: reduceTransparency)
        cache[key] = theme
        return theme
    }

    private init(palette p: Palette, highContrast: Bool, reduceTransparency: Bool) {
        palette = p
        self.highContrast = highContrast
        self.reduceTransparency = reduceTransparency
        let text = Color(hex: p.text)
        tint = Color(hex: p.tint)
        self.text = text
        secondary = highContrast ? text.opacity(0.88) : p.readable(p.secondary, minimum: 4.5).color
        surface = text.opacity(highContrast ? 0.12 : (p.isDark ? 0.07 : 0.05))
        surfaceHover = text.opacity(highContrast ? 0.18 : (p.isDark ? 0.12 : 0.09))
        stroke = text.opacity(highContrast ? 0.45 : (p.isDark ? 0.12 : 0.10))
        track = text.opacity(highContrast ? 0.30 : (p.isDark ? 0.12 : 0.10))
        blooms = reduceTransparency ? nil : p.backdrop?.map { Color(hex: $0) }

        var moods: [Mood: MoodColors] = [:]
        for mood in Mood.allCases {
            let accent = Color(hex: p.accentHex(mood))
            let gradient = p.gradient(mood)?.map { Color(hex: $0) }
            let button = p.buttonColors(mood)
            moods[mood] = MoodColors(
                text: highContrast ? text : p.readable(p.accentHex(mood), minimum: 4.5).color,
                shape: p.readable(p.accentHex(mood), minimum: 3).color,
                ring: gradient ?? [accent.opacity(0.55), accent],
                ringIsGradient: gradient != nil,
                glow: gradient?.dropFirst().first ?? accent,
                button: ButtonFill(stops: button.stops.map(\.color), label: button.label.color),
                wash: mood == .rest ? accent : nil
            )
        }
        self.moods = moods
    }
}

/// Hands its content the theme for a palette, adjusted for the Mac's
/// accessibility settings.
struct Themed<Content: View>: View {
    let palette: Palette
    @ViewBuilder let content: (AppTheme) -> Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ palette: Palette, @ViewBuilder content: @escaping (AppTheme) -> Content) {
        self.palette = palette
        self.content = content
    }

    var body: some View {
        content(AppTheme.resolve(palette, highContrast: contrast == .increased,
                                 reduceTransparency: reduceTransparency))
    }
}

extension Color {
    /// #RRGGBB or #RRGGBBAA.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
