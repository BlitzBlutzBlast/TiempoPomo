import AppKit
import CoreImage
import SwiftUI

/// Blurs whatever is behind the window: the base of the glass look.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        v.material = material
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
    }
}

/// A faint paper grain over the glass, made once with Core Image.
struct GrainOverlay: NSViewRepresentable {
    var opacity: Double

    func makeNSView(context: Context) -> GrainView { GrainView() }

    func updateNSView(_ v: GrainView, context: Context) {
        v.alphaValue = opacity
        v.isHidden = opacity <= 0.001
    }

    final class GrainView: NSView {
        static let tile: NSImage? = {
            guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else { return nil }
            let cropped = noise.cropped(to: CGRect(x: 0, y: 0, width: 192, height: 192))
            guard let mono = CIFilter(name: "CIColorControls", parameters: [
                kCIInputImageKey: cropped, kCIInputSaturationKey: 0, kCIInputContrastKey: 1.0,
            ])?.outputImage else { return nil }
            guard let cg = CIContext().createCGImage(mono, from: cropped.extent) else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: 96, height: 96))
        }()

        override var isOpaque: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            guard let tile = Self.tile else { return }
            NSColor(patternImage: tile).setFill()
            bounds.fill(using: .sourceOver)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// The window background: frosted glass under the theme's tint, with a soft
/// glow of the current phase's colour behind the dial.
struct GlassBackground: View {
    let theme: AppTheme
    var glow: Color? = nil

    var body: some View {
        ZStack {
            VisualEffectView(material: theme.material)
            if let blooms = theme.backdrop {
                BackdropBlooms(colors: blooms.map { Color(hex: $0) }, isDark: theme.isDark)
            }
            theme.tintColor.opacity(theme.tintOpacity)
            if let glow {
                RadialGradient(
                    colors: [glow.opacity(theme.isDark ? 0.24 : 0.14), glow.opacity(0)],
                    center: .center, startRadius: 20, endRadius: 340
                )
                .animation(.easeInOut(duration: 0.8), value: glow)
            }
            GrainOverlay(opacity: theme.grain)
        }
        .ignoresSafeArea()
    }
}

/// Large, heavily blurred pools of colour in the corners, for palettes that
/// light the glass from behind.
struct BackdropBlooms: View {
    let colors: [Color]
    let isDark: Bool

    // Where each bloom sits, as a fraction of the window, and its size.
    private let spots: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (0.05, 0.08, 0.75), (0.95, 0.15, 0.7), (0.1, 0.95, 0.7), (0.92, 0.9, 0.8),
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                ForEach(Array(colors.prefix(spots.count).enumerated()), id: \.offset) { i, color in
                    let spot = spots[i]
                    Circle()
                        .fill(color.opacity(isDark ? 0.55 : 0.35))
                        .frame(width: w * spot.size, height: w * spot.size)
                        .position(x: w * spot.x, y: h * spot.y)
                }
            }
            .blur(radius: 90)
        }
        .drawingGroup()
    }
}

/// Sets up the hosting window: draggable by its background, the theme's
/// light or dark appearance, and floating above other apps when asked.
struct WindowConfigurator: NSViewRepresentable {
    let theme: AppTheme
    let floats: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let theme = theme, floats = floats
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            // Only touch what is about to change: setting the appearance
            // again re-runs SwiftUI's update pass, which would call this
            // again, forever.
            if !window.isMovableByWindowBackground { window.isMovableByWindowBackground = true }
            if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
            if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
            let appearanceName: NSAppearance.Name = theme.isDark ? .darkAqua : .aqua
            if window.appearance?.name != appearanceName { window.appearance = NSAppearance(named: appearanceName) }
            let level: NSWindow.Level = floats ? .floating : .normal
            if window.level != level { window.level = level }
            if !window.collectionBehavior.contains(.fullScreenNone) { window.collectionBehavior.insert(.fullScreenNone) }
            let tint = NSColor(theme.tintColor)
            if window.backgroundColor != tint { window.backgroundColor = tint }
        }
    }
}

extension View {
    /// Glass background, appearance and accent for a sheet or settings pane.
    func themedPane(_ theme: AppTheme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(GlassBackground(theme: theme))
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.focus)
    }
}
