import AppKit
import SwiftUI

/// A colour set for the whole app. The palettes come from Glassine's themes:
/// the same glass tints and text colours, with the accent driving focus
/// rounds and a second, calmer colour for breaks.
struct AppTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let isDark: Bool
    let material: NSVisualEffectView.Material
    let tint: String
    let tintOpacity: Double
    let grain: Double
    let textHex: String
    let secondaryHex: String
    let focusHex: String
    let breakHex: String

    var tintColor: Color { Color(hex: tint) }
    var text: Color { Color(hex: textHex) }
    var secondary: Color { Color(hex: secondaryHex) }
    var focus: Color { Color(hex: focusHex) }
    var rest: Color { Color(hex: breakHex) }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    /// Fill for cards and quiet buttons.
    var surface: Color { text.opacity(isDark ? 0.07 : 0.05) }
    var stroke: Color { text.opacity(isDark ? 0.12 : 0.10) }
    /// Text on a filled accent button.
    var onAccent: Color { isDark ? Color.black.opacity(0.82) : .white }

    func accent(for phase: Phase) -> Color {
        switch phase {
        case .shortBreak, .longBreak: return rest
        case .complete: return secondary
        case .idle, .focus: return focus
        }
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

    static let all: [AppTheme] = [dusk, ocean, lavender, graphite, sepiaNight, midnight, moss, frost, paper]
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
