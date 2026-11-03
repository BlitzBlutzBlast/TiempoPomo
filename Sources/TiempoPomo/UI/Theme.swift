import AppKit
import SwiftUI

/// A colour set for the whole app. Most palettes come from Glassine's themes:
/// the same glass tints and text colours, with the accent driving focus
/// rounds and a second, calmer colour for breaks. A palette can also give the
/// ring a multi-colour gradient, lay coloured light behind the glass, and
/// pick its own typeface.
struct AppTheme: Identifiable, Hashable {
    var id: String
    var name: String
    var isDark: Bool
    var material: NSVisualEffectView.Material
    var tint: String
    var tintOpacity: Double
    var grain: Double
    var textHex: String
    var secondaryHex: String
    var focusHex: String
    var breakHex: String
    /// Ring and button colours for focus, when one accent isn't enough.
    var focusGradient: [String]? = nil
    var breakGradient: [String]? = nil
    /// Colours of the soft blooms of light behind the glass.
    var backdrop: [String]? = nil
    /// SF Pro by default, like the rest of macOS; a palette can choose another face.
    var fontDesign: Font.Design = .default
    /// Overrides the "done" colour, which is otherwise the secondary text colour.
    var doneHex: String? = nil
    /// Set by `adjusted(for:)` when the Mac asks for more contrast.
    var highContrast = false

    var tintColor: Color { Color(hex: tint) }
    var text: Color { Color(hex: textHex) }
    var secondary: Color { highContrast ? text.opacity(0.88) : Color(hex: secondaryHex) }
    var focus: Color { Color(hex: focusHex) }
    var rest: Color { Color(hex: breakHex) }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    /// Fill for cards and quiet buttons.
    var surface: Color { text.opacity(highContrast ? 0.12 : (isDark ? 0.07 : 0.05)) }
    var stroke: Color { text.opacity(highContrast ? 0.45 : (isDark ? 0.12 : 0.10)) }
    /// Text on a filled accent button.
    var onAccent: Color { isDark ? Color.black.opacity(0.82) : .white }

    func accent(for phase: Phase) -> Color {
        switch phase {
        case .shortBreak, .longBreak: return rest
        case .complete: return doneHex.map { Color(hex: $0) } ?? focus
        case .idle, .focus: return focus
        }
    }

    /// The ring's colours for a phase: the palette's gradient, or its accent
    /// fading in from behind.
    func ringColors(for phase: Phase) -> [Color] {
        let stops: [String]?
        switch phase {
        case .shortBreak, .longBreak: stops = breakGradient
        case .idle, .focus: stops = focusGradient
        case .complete: stops = nil
        }
        if let stops { return stops.map { Color(hex: $0) } }
        let a = accent(for: phase)
        return [a.opacity(0.55), a]
    }

    var isGradient: Bool { focusGradient != nil }

    /// The palette as the Mac's accessibility settings want it: solid
    /// instead of glass with Reduce Transparency, stronger text and edges
    /// with Increase Contrast.
    func adjusted(reduceTransparency: Bool, increaseContrast: Bool) -> AppTheme {
        var t = self
        if reduceTransparency {
            t.tintOpacity = 1
            t.grain = 0
            t.backdrop = nil
        }
        t.highContrast = increaseContrast
        return t
    }
}

/// Hands its content the palette adjusted for the Mac's accessibility settings.
struct Themed<Content: View>: View {
    let base: AppTheme
    @ViewBuilder let content: (AppTheme) -> Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    init(_ base: AppTheme, @ViewBuilder content: @escaping (AppTheme) -> Content) {
        self.base = base
        self.content = content
    }

    var body: some View {
        content(base.adjusted(reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased))
    }
}

extension AppTheme {
    static let dusk = AppTheme(
        id: "dusk", name: "Dusk", isDark: true, material: .hudWindow,
        tint: "#42316A", tintOpacity: 0.6, grain: 0.04,
        textHex: "#DFE5F4", secondaryHex: "#A7B3CF", focusHex: "#01B6E9", breakHex: "#BA88E7")
    static let ocean = AppTheme(
        id: "ocean", name: "Ocean", isDark: true, material: .hudWindow,
        tint: "#263152", tintOpacity: 0.45, grain: 0.05,
        textHex: "#DCE2F0", secondaryHex: "#A7B3CF", focusHex: "#45A8E5", breakHex: "#7FD1C7")
    static let lavender = AppTheme(
        id: "lavender", name: "Lavender", isDark: true, material: .hudWindow,
        tint: "#4D3C34", tintOpacity: 0.62, grain: 0.03,
        textHex: "#FFF2DE", secondaryHex: "#C4B09A", focusHex: "#BA88E7", breakHex: "#00E1FF")
    static let graphite = AppTheme(
        id: "graphite", name: "Graphite", isDark: true, material: .underWindowBackground,
        tint: "#141416", tintOpacity: 0.55, grain: 0,
        textHex: "#E6E4E1", secondaryHex: "#B9B5AE", focusHex: "#D0784A", breakHex: "#9DB4C0")
    static let sepiaNight = AppTheme(
        id: "sepia-night", name: "Sepia Night", isDark: true, material: .hudWindow,
        tint: "#1B1512", tintOpacity: 0.62, grain: 0.03,
        textHex: "#EADBC8", secondaryHex: "#C4B09A", focusHex: "#C64B21", breakHex: "#E0A85F")
    static let midnight = AppTheme(
        id: "midnight", name: "Midnight", isDark: true, material: .underWindowBackground,
        tint: "#0A0F1E", tintOpacity: 0.5, grain: 0,
        textHex: "#DCE2F0", secondaryHex: "#A7B3CF", focusHex: "#6FA8FF", breakHex: "#B79CFF")
    static let moss = AppTheme(
        id: "moss", name: "Moss", isDark: true, material: .underWindowBackground,
        tint: "#0F1512", tintOpacity: 0.55, grain: 0.02,
        textHex: "#DCE7DC", secondaryHex: "#AFC2AF", focusHex: "#84BF39", breakHex: "#E5C76B")
    static let frost = AppTheme(
        id: "frost", name: "Frost", isDark: false, material: .underWindowBackground,
        tint: "#F6F7FA", tintOpacity: 0.55, grain: 0,
        textHex: "#26282E", secondaryHex: "#6B6F7A", focusHex: "#3F8DE0", breakHex: "#2FA58A")
    static let paper = AppTheme(
        id: "paper", name: "Paper", isDark: false, material: .titlebar,
        tint: "#FBFAF8", tintOpacity: 0.9, grain: 0.05,
        textHex: "#2C1611", secondaryHex: "#7A6560", focusHex: "#C64B21", breakHex: "#3F8DE0")

    /// Apple's dark-mode system colours, at full strength: a ring that runs
    /// pink to orange to purple to blue, over glass lit from behind by blooms
    /// of the same colours.
    static let vivid = AppTheme(
        id: "vivid", name: "Vivid", isDark: true, material: .hudWindow,
        tint: "#100C24", tintOpacity: 0.62, grain: 0.03,
        textHex: "#F5F5F7", secondaryHex: "#A1A1AA", focusHex: "#FF375F", breakHex: "#64D2FF",
        focusGradient: ["#FF375F", "#FF9F0A", "#BF5AF2", "#0A84FF", "#FF375F"],
        breakGradient: ["#64D2FF", "#30D158", "#0A84FF", "#5E5CE6", "#64D2FF"],
        backdrop: ["#BF5AF2", "#FF375F", "#0A84FF", "#FF9F0A"],
        doneHex: "#30D158")

    /// Anthropic's brand palette: ink on warm paper, the orange accent for
    /// focus, blue for breaks, green when done, and a serif face.
    static let claude = AppTheme(
        id: "claude", name: "Claude", isDark: false, material: .titlebar,
        tint: "#FAF9F5", tintOpacity: 0.94, grain: 0.04,
        textHex: "#141413", secondaryHex: "#6B6A64", focusHex: "#D97757", breakHex: "#6A9BCC",
        fontDesign: .serif, doneHex: "#788C5D")

    static let all: [AppTheme] = [dusk, ocean, lavender, graphite, sepiaNight, midnight, moss, frost, paper, vivid, claude]
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
