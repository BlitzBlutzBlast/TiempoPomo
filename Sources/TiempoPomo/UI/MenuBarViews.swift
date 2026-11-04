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
    /// The popover's own window, so picking a destination can close it.
    @State private var panelWindow: NSWindow?

    var body: some View {
        Themed(settings.theme) { theme in
            let accent = theme.accent(for: engine.displayPhase)
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Label(engine.phase == .idle ? "Ready" : engine.phase.label, systemImage: engine.phase.symbol)
                        .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                        .foregroundStyle(theme.accentText(for: engine.displayPhase))
                    Spacer()
                    Text(engine.plan.name)
                        .font(.system(size: 12, design: theme.fontDesign))
                        .foregroundStyle(theme.secondary)
                        .lineLimit(1)
                }

                PanelTime(countdown: engine.countdown, theme: theme, accent: theme.accentShape(for: engine.displayPhase),
                          roundText: engine.plan.rounds > 1 || engine.plan.repeatForever ? engine.roundText : nil)

                HStack(spacing: 10) {
                    Button(action: engine.toggle) {
                        Text(engine.isRunning ? "Pause" : (engine.phaseStarted ? "Resume" : "Start"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(theme: theme, fill: theme.buttonFill(for: engine.displayPhase)))
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
                    // The palette's own pill rather than a system pop-up, which
                    // takes on the accent and can lose contrast on dark palettes.
                    Menu {
                        ForEach(store.presets) { preset in
                            Button {
                                store.selectedID = preset.id
                                engine.load(store.selected)
                            } label: {
                                Label(preset.name, systemImage: preset.id == store.selectedID ? "checkmark" : preset.symbol)
                            }
                        }
                    } label: {
                        PillLabel(theme: theme) {
                            Image(systemName: engine.plan.symbol)
                            Text(engine.plan.name).lineLimit(1)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .opacity(0.7)
                        }
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .focusEffectDisabled()
                    .accessibilityLabel("Session: \(engine.plan.name)")
                }

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    panelLink("Open Tiempo Pomo", "macwindow") {
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
                    panelLink("Quit Tiempo Pomo", "power") { NSApp.terminate(nil) }
                }
                .font(.system(size: 13, design: theme.fontDesign))
                .foregroundStyle(theme.text)
            }
            .padding(16)
            .frame(width: 280)
            // The glass fills the whole popover window, edge to edge, so none
            // of the system's own window background shows above or below.
            .background {
                GlassBackground(theme: Self.popoverGlass(theme), breakTint: engine.phase.isBreak ? theme.rest : nil)
                    .ignoresSafeArea()
            }
            .background(CountdownVisibility(countdown: engine.countdown))
            .background(PanelWindowReader(window: $panelWindow, isDark: theme.isDark))
            .preferredColorScheme(theme.colorScheme)
            .tint(accent)
        }
    }

    /// A row that goes somewhere: it closes the popover first, so the window
    /// it opens isn't left covered.
    /// The popover floats over whatever is behind it and is mostly small
    /// text, so its glass is never thinner than this, whatever the palette.
    /// Otherwise a bright wallpaper shows through a light tint (Ocean's is
    /// 45%) and washes the text out.
    static func popoverGlass(_ theme: AppTheme) -> AppTheme {
        var glass = theme
        glass.tintOpacity = max(theme.tintOpacity, 0.72)
        return glass
    }

    private func panelLink(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            panelWindow?.orderOut(nil)
            action()
        } label: {
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

/// Finds the window this view is in (the menu bar popover's).
/// Finds the window this view is in (the menu bar popover's), and gives it
/// the palette's light or dark appearance. Without that the popover follows
/// the Mac's appearance, so a dark palette's glass is drawn light and its
/// text loses contrast. The window's own background is cleared so only the
/// palette's glass shows.
private struct PanelWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?
    let isDark: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let isDark = isDark
        DispatchQueue.main.async {
            guard let found = view.window else { return }
            if window !== found { window = found }
            let name: NSAppearance.Name = isDark ? .darkAqua : .aqua
            if found.appearance?.name != name { found.appearance = NSAppearance(named: name) }
            if found.backgroundColor != .clear { found.backgroundColor = .clear }
        }
    }
}
