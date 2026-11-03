import SwiftUI

/// The countdown shown in the menu bar. It watches only `MenuBarClock`,
/// which changes once a minute by default.
struct MenuBarLabel: View {
    @ObservedObject var clock: MenuBarClock

    var body: some View {
        if let text = clock.text {
            HStack(spacing: 4) {
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
struct MenuBarPanel: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var store: PresetStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Themed(settings.theme) { theme in
            let accent = theme.accent(for: engine.displayPhase)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label(engine.phase == .idle ? "Ready" : engine.phase.label, systemImage: engine.phase.symbol)
                        .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(engine.plan.name)
                        .font(.system(size: 12, design: theme.fontDesign))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }

                PanelTime(countdown: engine.countdown, theme: theme, accent: accent,
                          roundText: engine.plan.rounds > 1 || engine.plan.repeatForever ? engine.roundText : nil)

                HStack(spacing: 10) {
                    Button(action: engine.toggle) {
                        Text(engine.isRunning ? "Pause" : (engine.phaseStarted ? "Resume" : "Start"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(theme: theme, accent: accent,
                                                   colors: theme.ringColors(for: engine.displayPhase)))
                    if !engine.isIdle {
                        Button(action: engine.reset) { Image(systemName: "arrow.counterclockwise") }
                            .buttonStyle(CircleIconButtonStyle(theme: theme))
                            .accessibilityLabel("Reset")
                        Button(action: engine.skip) { Image(systemName: "forward.end") }
                            .buttonStyle(CircleIconButtonStyle(theme: theme))
                            .accessibilityLabel(engine.phase.isBreak ? "Skip break" : "Skip to break")
                    }
                }

                if engine.isIdle {
                    Picker("Session", selection: Binding(
                        get: { store.selectedID },
                        set: { id in
                            store.selectedID = id
                            engine.load(store.selected)
                        }
                    )) {
                        ForEach(store.presets) { Text($0.name).tag($0.id) }
                    }
                    .font(.system(size: 12, design: theme.fontDesign))
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    panelLink("Open PomTiempo", "macwindow") {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    if settings.showMiniTimer {
                        panelLink("Hide Mini Timer", "pip.exit") { dismissWindow(id: "mini") }
                    } else {
                        panelLink("Show Mini Timer", "pip.enter") { openWindow(id: "mini") }
                    }
                    panelLink("Settings…", "gearshape") {
                        openSettings()
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    panelLink("Quit PomTiempo", "power") { NSApp.terminate(nil) }
                }
                .font(.system(size: 13, design: theme.fontDesign))
                .foregroundStyle(theme.text)
            }
            .padding(16)
            .frame(width: 280)
            .background(GlassBackground(theme: theme, breakTint: engine.phase.isBreak ? theme.rest : nil))
            .background(CountdownVisibility(countdown: engine.countdown))
            .preferredColorScheme(theme.colorScheme)
            .tint(accent)
        }
    }

    private func panelLink(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(PanelRowStyle())
    }
}

private struct PanelRowStyle: ButtonStyle {
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(hovering || configuration.isPressed ? 0.08 : 0)))
            .onHover { hovering = $0 }
    }
}

private struct PanelTime: View {
    @ObservedObject var countdown: Countdown
    let theme: AppTheme
    let accent: Color
    let roundText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(Format.clock(TimeInterval(countdown.seconds)))
                    .font(.system(size: 40, weight: .light, design: theme.fontDesign))
                    .monospacedDigit()
                    .foregroundStyle(theme.text)
                Spacer()
                if let roundText {
                    Text(roundText)
                        .font(.system(size: 11, design: theme.fontDesign))
                        .foregroundStyle(theme.secondary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.stroke)
                    Capsule().fill(accent)
                        .frame(width: max(4, proxy.size.width * countdown.fraction))
                }
            }
            .frame(height: 4)
            .accessibilityHidden(true)
        }
    }
}
