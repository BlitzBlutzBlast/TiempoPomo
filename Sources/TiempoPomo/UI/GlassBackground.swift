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

/// The palette's glass, painted edge to edge as the bottom layer of a
/// surface: frosted blur, the palette's tint at the surface's strength, its
/// blooms if it has any, and during breaks a wash of the break colour so the
/// phase reads from across the room.
struct GlassBackground: View {
    let theme: AppTheme
    let surface: GlassSurface
    let phase: Phase

    var body: some View {
        let wash = theme.colors(for: phase).wash
        ZStack {
            VisualEffectView(material: theme.material)
            if let blooms = theme.blooms {
                BackdropBlooms(colors: blooms, isDark: theme.isDark)
            }
            theme.tint.opacity(theme.glassOpacity(surface))
            (wash ?? .clear)
                .opacity(theme.isDark ? 0.16 : 0.10)
                .animation(.easeInOut(duration: 0.8), value: wash)
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

// MARK: - Window bridge

/// The one link between a SwiftUI surface and the AppKit window it sits in.
/// It shapes the window (title bar, level, appearance, background), tells the
/// countdown whether the window is on screen, and reports the window itself
/// as it opens and closes. The main window, the popover and the mini timer
/// each describe what they need with a `Style`.
struct WindowBridge: NSViewRepresentable {
    enum Chrome: Equatable {
        /// A standard window with its title hidden and its glass reaching into
        /// the title bar (the main window).
        case hiddenTitle
        /// No title bar at all; the window is exactly this size (the mini timer).
        case borderless(CGSize)
        /// Leave the window's frame alone (the menu bar popover).
        case system
    }

    struct Style: Equatable {
        var isDark: Bool
        var chrome: Chrome
        var floats = false
        /// Show on every Space and beside full-screen apps.
        var allSpaces = false
        /// The window's own background, behind the glass; nil leaves it be.
        var background: NSColor?
    }

    let style: Style
    /// Counted as watching while the window is on screen.
    var countdown: Countdown? = nil
    /// Given the window when it appears, and nil when it closes.
    var onWindow: ((NSWindow?) -> Void)? = nil

    func makeNSView(context: Context) -> BridgeView {
        let v = BridgeView()
        v.countdown = countdown
        v.onWindow = onWindow
        v.style = style
        return v
    }

    func updateNSView(_ v: BridgeView, context: Context) {
        v.onWindow = onWindow
        if v.style != style {
            v.style = style
            v.applyStyleSoon()
        }
    }

    static func dismantleNSView(_ v: BridgeView, coordinator: ()) {
        v.reportVisible(false)
    }

    final class BridgeView: NSView {
        var style: Style?
        weak var countdown: Countdown?
        var onWindow: ((NSWindow?) -> Void)?
        // Only touched on the main thread; deinit just unregisters them.
        nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else {
                reportVisible(false)
                return
            }
            let center = NotificationCenter.default
            observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportVisible(window.occlusionState.contains(.visible)) }
            })
            observers.append(center.addObserver(forName: NSWindow.willCloseNotification,
                                                object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reportVisible(false)
                    self?.onWindow?(nil)
                }
            })
            reportVisible(window.occlusionState.contains(.visible))
            let report = onWindow
            DispatchQueue.main.async { report?(window) }
            applyStyleSoon()
        }

        func reportVisible(_ visible: Bool) {
            countdown?.setVisible(visible, for: ObjectIdentifier(self))
        }

        /// Applies the style on the next turn of the run loop, touching only
        /// what differs: setting a window's appearance again re-runs SwiftUI's
        /// update pass, which would call this again, forever.
        func applyStyleSoon() {
            DispatchQueue.main.async { [weak self] in
                guard let self, let window = self.window, let style = self.style else { return }
                Self.apply(style, to: window)
            }
        }

        private static func apply(_ style: Style, to window: NSWindow) {
            let name: NSAppearance.Name = style.isDark ? .darkAqua : .aqua
            if window.appearance?.name != name { window.appearance = NSAppearance(named: name) }
            let level: NSWindow.Level = style.floats ? .floating : .normal
            if window.level != level { window.level = level }
            if let background = style.background, window.backgroundColor != background {
                window.backgroundColor = background
            }
            var behavior = window.collectionBehavior
            if style.allSpaces { behavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary]) }

            switch style.chrome {
            case .hiddenTitle:
                if !window.isMovableByWindowBackground { window.isMovableByWindowBackground = true }
                if !window.titlebarAppearsTransparent { window.titlebarAppearsTransparent = true }
                if window.titleVisibility != .hidden { window.titleVisibility = .hidden }
                behavior.insert(.fullScreenNone)
            case .borderless(let size):
                if window.styleMask.contains(.titled) {
                    let frame = window.frame
                    window.styleMask.remove(.titled)
                    window.setFrame(NSRect(x: frame.minX, y: frame.maxY - size.height,
                                           width: size.width, height: size.height), display: true)
                }
                for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                    if window.standardWindowButton(button)?.isHidden == false {
                        window.standardWindowButton(button)?.isHidden = true
                    }
                }
                if !window.isMovableByWindowBackground { window.isMovableByWindowBackground = true }
                if window.isOpaque { window.isOpaque = false }
            case .system:
                break
            }
            if window.collectionBehavior != behavior { window.collectionBehavior = behavior }
        }

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }
    }
}
