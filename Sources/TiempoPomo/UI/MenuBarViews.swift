import SwiftUI

/// The countdown shown in the menu bar. It watches only `MenuBarClock`,
/// which changes once a minute by default.
struct MenuBarLabel: View {
    @ObservedObject var clock: MenuBarClock

    var body: some View {
        if let text = clock.text {
            HStack(spacing: Space.xs) {
                Image(systemName: clock.symbol)
                Text(text).monospacedDigit()
            }
        } else {
            Image(systemName: clock.symbol)
        }
    }
}

/// The menu bar popover: the time, the controls, the session, and the way to
/// the full window, the mini timer and Settings.
///
/// Its structure is fixed: one frame of one width, the palette's glass as the
/// bottom layer filling every edge, and content that keeps the same shape in
/// every state. The palette only paints; it never changes the popover's size.
struct MenuBarPanel: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: TimerEngine
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismissWindow) private var dismissWindow
    /// The popover's own window, so picking a destination can close it.
    @State private var panelWindow: NSWindow?

    static let width: CGFloat = 280

    var body: some View {
        Themed(settings.palette) { theme in
            ZStack(alignment: .top) {
                GlassBackground(theme: theme, surface: .floating, phase: engine.phase)
                content(theme: theme)
                    .padding(Space.l)
            }
            .frame(width: Self.width)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(WindowBridge(
                style: .init(isDark: theme.isDark, chrome: .system, background: .clear),
                countdown: engine.countdown,
                onWindow: { panelWindow = $0 }))
            .preferredColorScheme(theme.colorScheme)
            .tint(theme.colors(for: engine.displayPhase).shape)
        }
    }

    private func content(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: Space.m + 2) {
            HStack(alignment: .firstTextBaseline) {
                PhaseLabel(phase: engine.phase, theme: theme)
                Spacer()
                if engine.showsRounds {
                    Text(engine.roundText)
                        .textRole(.small, theme)
                        .foregroundStyle(theme.secondary)
                }
            }

            VStack(alignment: .leading, spacing: Space.s) {
                CountdownText(countdown: engine.countdown, role: .panelTime, theme: theme)
                ProgressBar(countdown: engine.countdown,
                            color: theme.colors(for: engine.displayPhase).shape, track: theme.track)
            }

            TimerControls(theme: theme, fillsWidth: true)

            SessionMenu(theme: theme, fillsWidth: true) { go { open(.sessions) } }

            Divider()

            VStack(alignment: .leading, spacing: Space.xxs) {
                row("Open Tiempo Pomo", "macwindow") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                if settings.showMiniTimer {
                    row("Hide Mini Timer", "pip.exit") { dismissWindow(id: "mini") }
                } else {
                    row("Show Mini Timer", "pip.enter") { openWindow(id: "mini") }
                }
                row("Settings…", "gearshape") { open(.general) }
                row("Quit Tiempo Pomo", "power") { NSApp.terminate(nil) }
            }
        }
    }

    private func open(_ tab: AppSettings.SettingsTab) {
        settings.settingsTab = tab
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the popover first, so the window a destination opens isn't
    /// left covered.
    private func go(_ action: () -> Void) {
        panelWindow?.orderOut(nil)
        action()
    }

    private func row(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button { go(action) } label: { Label(title, systemImage: symbol) }
            .buttonStyle(QuietButtonStyle(theme: settings.theme, shape: .row))
    }
}
