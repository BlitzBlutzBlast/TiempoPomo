import SwiftUI

// The app's design scale, in one place. Every surface (the main window, the
// menu bar popover, the mini timer) takes its type, spacing, corners and
// glass from here, so they read as one app whichever palette is chosen.
//
// The palette's typeface applies to those timer surfaces. Settings and the
// small editing popovers use standard macOS type, like any Mac app's.

/// The named text styles. Sizes, weights and tracking live here only.
enum TextRole {
    /// The big countdown in the main window.
    case dialTime
    /// The countdown in the menu bar popover.
    case panelTime
    /// The countdown in the mini timer.
    case pillTime
    /// "Session complete".
    case title
    /// The window title and the Start/Pause button.
    case headline
    /// Rows in the popover.
    case body
    /// Pills and quiet buttons.
    case control
    /// The phase name above the time, in tracked capitals.
    case label
    /// Secondary lines: up next, the session name, today's totals.
    case caption
    /// The smallest text: round counts, the mini timer's phase.
    case small
    /// The "Space" keycap.
    case keycap

    var size: CGFloat {
        switch self {
        case .dialTime: return 60
        case .panelTime: return 40
        case .pillTime: return 19
        case .title: return 20
        case .headline: return 15
        case .body, .control: return 13
        case .label, .caption: return 12
        case .small: return 11
        case .keycap: return 10
        }
    }

    var weight: Font.Weight {
        switch self {
        case .dialTime, .panelTime: return .light
        case .pillTime, .control: return .medium
        case .title, .headline, .label, .keycap: return .semibold
        case .body, .caption, .small: return .regular
        }
    }

    var tracking: CGFloat { self == .label ? 1.4 : 0 }

    func font(_ design: Font.Design) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

extension View {
    /// Sets the font and tracking for a text style in the palette's typeface.
    func textRole(_ role: TextRole, _ theme: AppTheme) -> some View {
        font(role.font(theme.fontDesign)).tracking(role.tracking)
    }
}

/// Spacing steps. Everything is laid out on these.
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
}

/// Corner radii. Pills and the round buttons use capsules and circles.
enum Radius {
    /// Keycaps, list rows, icon tiles.
    static let small: CGFloat = 6
    /// Palette swatches and the mini timer.
    static let large: CGFloat = 16
}

/// How strong the palette's glass is on each kind of surface.
enum GlassSurface {
    /// The main window: the palette's own glass.
    case window
    /// The popover and the mini timer float over whatever is behind them and
    /// are mostly small text, so their glass is never thinner than 72%.
    case floating

    static let floatingMinimum = 0.72
}
