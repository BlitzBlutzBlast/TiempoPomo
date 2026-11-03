import AppKit
import SwiftUI

/// A small always-on-top pill: progress, time, play/pause, and a way back to
/// the main window. Drag it anywhere; it follows you across Spaces.
struct MiniTimerView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: TimerEngine
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var hovering = false

    var body: some View {
        Themed(settings.theme) { theme in
            let accent = theme.accent(for: engine.displayPhase)
            HStack(spacing: 10) {
                MiniProgress(countdown: engine.countdown, accent: theme.accentShape(for: engine.displayPhase), track: theme.stroke,
                             symbol: engine.phase.symbol)
                MiniTime(countdown: engine.countdown, theme: theme, phase: engine.phase)
                Spacer(minLength: 4)
                Button(action: engine.toggle) {
                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.buttonFill(for: engine.displayPhase).label)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(theme.buttonFill(for: engine.displayPhase).stops[0]))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.isRunning ? "Pause" : "Start")
                VStack(spacing: 2) {
                    Button {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                        dismissWindow(id: "mini")
                    } label: {
                        Image(systemName: "pip.exit")
                            .frame(width: 20, height: 18)
                    }
                    .help("Back to the full window")
                    .accessibilityLabel("Open the full window")
                    Button {
                        dismissWindow(id: "mini")
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 20, height: 18)
                    }
                    .help("Hide the mini timer (turn it back on in Settings › General or the menu bar)")
                    .accessibilityLabel("Hide mini timer")
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.secondary.opacity(hovering ? 1 : 0.6))
            }
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(width: 236, height: 50)
            .background(GlassBackground(theme: theme, breakTint: engine.phase.isBreak ? theme.rest : nil))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.stroke))
            .background(MiniWindowConfigurator(isDark: theme.isDark) { open in
                if settings.showMiniTimer != open { settings.showMiniTimer = open }
            })
            .background(CountdownVisibility(countdown: engine.countdown))
            .preferredColorScheme(theme.colorScheme)
            .onHover { hovering = $0 }
            // Fill the whole window, title bar area included, so the window
            // is exactly the pill.
            .ignoresSafeArea()

        }
    }
}

private struct MiniProgress: View {
    @ObservedObject var countdown: Countdown
    let accent: Color
    let track: Color
    let symbol: String

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: 3)
            Circle()
                .trim(from: 0, to: countdown.fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }
}

private struct MiniTime: View {
    @ObservedObject var countdown: Countdown
    let theme: AppTheme
    let phase: Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Format.clock(TimeInterval(countdown.seconds)))
                .font(.system(size: 19, weight: .medium, design: theme.fontDesign))
                .monospacedDigit()
                .foregroundStyle(theme.text)
            Text(phase.label)
                .font(.system(size: 10, weight: .medium, design: theme.fontDesign))
                .foregroundStyle(theme.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Makes the mini window a borderless, floating, draggable pill that shows
/// on every Space.
private struct MiniWindowConfigurator: NSViewRepresentable {
    let isDark: Bool
    /// Told when the window opens and closes, however it was closed.
    let onOpenChange: (Bool) -> Void

    func makeNSView(context: Context) -> Watcher {
        let v = Watcher()
        v.onOpenChange = onOpenChange
        return v
    }

    final class Watcher: NSView {
        var onOpenChange: ((Bool) -> Void)?
        private var closeObserver: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
            closeObserver = nil
            guard let window else { return }
            onOpenChange?(true)
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self] _ in self?.onOpenChange?(false) }
        }

        deinit {
            if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        }
    }

    func updateNSView(_ view: Watcher, context: Context) {
        let isDark = isDark
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            if window.level != .floating { window.level = .floating }
            // No title bar at all, so the window is exactly the pill.
            if window.styleMask.contains(.titled) {
                let frame = window.frame
                window.styleMask.remove(.titled)
                window.setFrame(NSRect(x: frame.minX, y: frame.maxY - 50, width: 236, height: 50), display: true)
            }
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                if window.standardWindowButton(button)?.isHidden == false {
                    window.standardWindowButton(button)?.isHidden = true
                }
            }
            if !window.isMovableByWindowBackground { window.isMovableByWindowBackground = true }
            if window.isOpaque { window.isOpaque = false }
            if window.backgroundColor != .clear { window.backgroundColor = .clear }
            let behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            if !window.collectionBehavior.isSuperset(of: behavior) { window.collectionBehavior.formUnion(behavior) }
            let name: NSAppearance.Name = isDark ? .darkAqua : .aqua
            if window.appearance?.name != name { window.appearance = NSAppearance(named: name) }
        }
    }
}
