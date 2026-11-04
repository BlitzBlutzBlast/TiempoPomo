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

    static let size = CGSize(width: 236, height: 50)

    var body: some View {
        Themed(settings.palette) { theme in
            let colors = theme.colors(for: engine.displayPhase)
            HStack(spacing: Space.s + Space.xxs) {
                ZStack {
                    ProgressRing(fraction: engine.countdown.fraction, colors: colors, lineWidth: 3, track: theme.track)
                    Image(systemName: engine.phase.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colors.shape)
                }
                .frame(width: 28, height: 28)
                .modifier(TickRedraw(countdown: engine.countdown))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    CountdownText(countdown: engine.countdown, role: .pillTime, theme: theme)
                    Text(engine.phase.label)
                        .textRole(.small, theme)
                        .foregroundStyle(theme.secondary)
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: Space.xs)

                Button(action: engine.toggle) {
                    Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(colors.button.label)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(colors.button.stops[0]))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.primaryActionTitle)

                VStack(spacing: Space.xxs) {
                    Button {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                        dismissWindow(id: "mini")
                    } label: {
                        Image(systemName: "pip.exit").frame(width: 20, height: 18)
                    }
                    .help("Back to the full window")
                    .accessibilityLabel("Open the full window")
                    Button {
                        dismissWindow(id: "mini")
                    } label: {
                        Image(systemName: "xmark").frame(width: 20, height: 18)
                    }
                    .help("Hide the mini timer (turn it back on in Settings › General or the menu bar)")
                    .accessibilityLabel("Hide mini timer")
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.secondary.opacity(hovering ? 1 : 0.6))
            }
            .padding(.leading, Space.s + Space.xxs)
            .padding(.trailing, Space.s)
            .frame(width: Self.size.width, height: Self.size.height)
            .background(GlassBackground(theme: theme, surface: .floating, phase: engine.phase))
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.large, style: .continuous).stroke(theme.stroke))
            .background(WindowBridge(
                style: .init(isDark: theme.isDark, chrome: .borderless(Self.size), floats: true,
                             allSpaces: true, background: .clear),
                countdown: engine.countdown,
                onWindow: { window in
                    let open = window != nil
                    if settings.showMiniTimer != open { settings.showMiniTimer = open }
                }))
            .preferredColorScheme(theme.colorScheme)
            .onHover { hovering = $0 }
            // Fill the whole window, title bar area included, so the window
            // is exactly the pill.
            .ignoresSafeArea()
        }
    }
}

/// Redraws its content when the countdown ticks, for small views that read
/// the countdown without being its own observer.
private struct TickRedraw: ViewModifier {
    @ObservedObject var countdown: Countdown
    func body(content: Content) -> some View { content }
}
