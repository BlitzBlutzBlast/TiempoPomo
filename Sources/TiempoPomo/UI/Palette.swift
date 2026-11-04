import AppKit
import SwiftUI

/// A palette as defined: its glass, its text colours and its accents, as hex
/// codes. Views never read a palette directly; `AppTheme` resolves it once
/// into ready-to-use colours, contrast-checked for the glass they sit on.
///
/// Most palettes come from Glassine's themes: the same glass tints and text
/// colours, with the accent driving focus rounds and a second, calmer colour
/// for breaks. A palette can also give the ring a multi-colour gradient, lay
/// coloured light behind the glass, and pick its own typeface.
struct Palette: Identifiable, Hashable {
    var id: String
    var name: String
    var isDark: Bool
    var material: NSVisualEffectView.Material
    var tint: String
    var tintOpacity: Double
    var grain: Double
    var text: String
    var secondary: String
    var focus: String
    var rest: String
    /// The "done" colour; the focus colour if not set.
    var done: String? = nil
    /// Ring and button colours, when one accent isn't enough.
    var focusGradient: [String]? = nil
    var breakGradient: [String]? = nil
    /// Colours of the soft blooms of light behind the glass.
    var backdrop: [String]? = nil
    /// SF Pro by default, like the rest of macOS.
    var fontDesign: Font.Design = .default
}

// MARK: - The palettes

extension Palette {
    static let dusk = Palette(
        id: "dusk", name: "Dusk", isDark: true, material: .hudWindow,
        tint: "#42316A", tintOpacity: 0.6, grain: 0.04,
        text: "#DFE5F4", secondary: "#A7B3CF", focus: "#01B6E9", rest: "#BA88E7")
    static let ocean = Palette(
        id: "ocean", name: "Ocean", isDark: true, material: .hudWindow,
        tint: "#263152", tintOpacity: 0.45, grain: 0.05,
        text: "#DCE2F0", secondary: "#A7B3CF", focus: "#45A8E5", rest: "#7FD1C7")
    static let lavender = Palette(
        id: "lavender", name: "Lavender", isDark: true, material: .hudWindow,
        tint: "#4D3C34", tintOpacity: 0.62, grain: 0.03,
        text: "#FFF2DE", secondary: "#C4B09A", focus: "#BA88E7", rest: "#00E1FF")
    static let graphite = Palette(
        id: "graphite", name: "Graphite", isDark: true, material: .underWindowBackground,
        tint: "#141416", tintOpacity: 0.55, grain: 0,
        text: "#E6E4E1", secondary: "#B9B5AE", focus: "#D0784A", rest: "#9DB4C0")
    static let sepiaNight = Palette(
        id: "sepia-night", name: "Sepia Night", isDark: true, material: .hudWindow,
        tint: "#1B1512", tintOpacity: 0.62, grain: 0.03,
        text: "#EADBC8", secondary: "#C4B09A", focus: "#C64B21", rest: "#E0A85F")
    static let midnight = Palette(
        id: "midnight", name: "Midnight", isDark: true, material: .underWindowBackground,
        tint: "#0A0F1E", tintOpacity: 0.5, grain: 0,
        text: "#DCE2F0", secondary: "#A7B3CF", focus: "#6FA8FF", rest: "#B79CFF")
    static let moss = Palette(
        id: "moss", name: "Moss", isDark: true, material: .underWindowBackground,
        tint: "#0F1512", tintOpacity: 0.55, grain: 0.02,
        text: "#DCE7DC", secondary: "#AFC2AF", focus: "#84BF39", rest: "#E5C76B")
    static let frost = Palette(
        id: "frost", name: "Frost", isDark: false, material: .underWindowBackground,
        tint: "#F6F7FA", tintOpacity: 0.55, grain: 0,
        text: "#26282E", secondary: "#6B6F7A", focus: "#3F8DE0", rest: "#2FA58A")
    static let paper = Palette(
        id: "paper", name: "Paper", isDark: false, material: .titlebar,
        tint: "#FBFAF8", tintOpacity: 0.9, grain: 0.05,
        text: "#2C1611", secondary: "#7A6560", focus: "#C64B21", rest: "#3F8DE0")

    /// Apple's dark-mode system colours, at full strength: a ring that runs
    /// pink to orange to purple to blue, over glass lit from behind by blooms
    /// of the same colours.
    static let vivid = Palette(
        id: "vivid", name: "Vivid", isDark: true, material: .hudWindow,
        tint: "#100C24", tintOpacity: 0.62, grain: 0.03,
        text: "#F5F5F7", secondary: "#A1A1AA", focus: "#FF375F", rest: "#64D2FF", done: "#30D158",
        focusGradient: ["#FF375F", "#FF9F0A", "#BF5AF2", "#0A84FF", "#FF375F"],
        breakGradient: ["#64D2FF", "#30D158", "#0A84FF", "#5E5CE6", "#64D2FF"],
        backdrop: ["#BF5AF2", "#FF375F", "#0A84FF", "#FF9F0A"])

    /// Anthropic's brand palette: ink on warm paper, the orange accent for
    /// focus, blue for breaks, green when done, and a serif face.
    static let claude = Palette(
        id: "claude", name: "Claude", isDark: false, material: .titlebar,
        tint: "#FAF9F5", tintOpacity: 0.94, grain: 0.04,
        text: "#141413", secondary: "#6B6A64", focus: "#D97757", rest: "#6A9BCC", done: "#788C5D",
        fontDesign: .serif)

    static let all: [Palette] = [dusk, ocean, lavender, graphite, sepiaNight, midnight, moss, frost, paper, vivid, claude]

    static func named(_ id: String) -> Palette { all.first { $0.id == id } ?? .dusk }
}

// MARK: - Contrast
//
// Text and small controls are checked against WCAG AA: 4.5:1 for text, 3:1
// for large text and shapes. The background is modelled the way the glass is
// drawn: macOS's window material, the palette's tint over it at its thinnest
// (the main window's), and, for Vivid, each coloured bloom behind that. A
// colour that falls short is nudged toward the palette's text colour just far
// enough to pass, so palettes keep their look and only what people read moves.

struct RGB: Equatable, Hashable {
    var r, g, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: String(s.prefix(6))).scanHexInt64(&v)
        self.init(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    func mixed(with other: RGB, _ t: Double) -> RGB {
        RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    var luminance: Double {
        func f(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)
    }

    func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    static let ink = RGB(hex: "#141416")
    static let white = RGB(1, 1, 1)
}

/// The three colour moods a phase can be in.
enum Mood: CaseIterable {
    case focus, rest, done

    init(_ phase: Phase) {
        switch phase {
        case .idle, .focus: self = .focus
        case .shortBreak, .longBreak: self = .rest
        case .complete: self = .done
        }
    }
}

extension Palette {
    /// The backgrounds text can sit on, worst cases included.
    var contrastBackgrounds: [RGB] {
        let base = isDark ? RGB(hex: "#2B2B2E") : RGB(hex: "#ECECEE")
        let tinted = base.mixed(with: RGB(hex: tint), tintOpacity)
        guard let backdrop else { return [tinted] }
        let bloomed = backdrop.map {
            base.mixed(with: RGB(hex: $0), isDark ? 0.55 : 0.35).mixed(with: RGB(hex: tint), tintOpacity)
        }
        return bloomed + [tinted]
    }

    func worstContrast(of c: RGB) -> Double {
        contrastBackgrounds.map { c.contrast(with: $0) }.min() ?? 21
    }

    /// The colour, or the nearest one toward the text colour that reaches
    /// `minimum` contrast on every background.
    func readable(_ hex: String, minimum: Double) -> RGB {
        let start = RGB(hex: hex), toward = RGB(hex: text)
        var t = 0.0, c = start
        while worstContrast(of: c) < minimum && t < 1 {
            t += 0.04
            c = start.mixed(with: toward, min(t, 1))
        }
        return c
    }

    func accentHex(_ mood: Mood) -> String {
        switch mood {
        case .focus: return focus
        case .rest: return rest
        case .done: return done ?? focus
        }
    }

    func gradient(_ mood: Mood) -> [String]? {
        switch mood {
        case .focus: return focusGradient
        case .rest: return breakGradient
        case .done: return nil
        }
    }

    /// The Start/Pause button: the gradient or accent, with ink or white
    /// text, whichever reads better. If neither reaches 4.5:1 on every colour
    /// of the button, the colours are eased lighter (for ink) or darker (for
    /// white) until it does.
    func buttonColors(_ mood: Mood) -> (stops: [RGB], label: RGB) {
        let accent = RGB(hex: accentHex(mood))
        var stops: [RGB] = gradient(mood).map { Array($0.dropLast()).map(RGB.init(hex:)) }
            ?? [accent, accent.mixed(with: contrastBackgrounds.last!, 0.22)]
        func worst(_ label: RGB) -> Double { stops.map { label.contrast(with: $0) }.min() ?? 21 }
        let label = worst(.ink) >= worst(.white) ? RGB.ink : RGB.white
        let toward = label == .ink ? RGB.white : RGB.ink
        let original = stops
        var t = 0.0
        while worst(label) < 4.5 && t < 0.6 {
            t += 0.03
            stops = original.map { $0.mixed(with: toward, t) }
        }
        return (stops, label)
    }

    /// Every contrast pair the app relies on, for the tests.
    var contrastChecks: [(what: String, ratio: Double, minimum: Double)] {
        var checks: [(String, Double, Double)] = [
            ("text", worstContrast(of: RGB(hex: text)), 4.5),
            ("secondary", worstContrast(of: readable(secondary, minimum: 4.5)), 4.5),
        ]
        for mood in Mood.allCases {
            checks.append(("\(mood) label", worstContrast(of: readable(accentHex(mood), minimum: 4.5)), 4.5))
            checks.append(("\(mood) shape", worstContrast(of: readable(accentHex(mood), minimum: 3)), 3))
            let button = buttonColors(mood)
            checks.append(("\(mood) button", button.stops.map { button.label.contrast(with: $0) }.min() ?? 21, 4.5))
        }
        return checks
    }
}
