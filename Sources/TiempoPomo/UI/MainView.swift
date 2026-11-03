import SwiftUI

/// The main window: everything centres on the dial. The session and its
/// timing sit just under it as two pills, the controls under those, and a
/// single quiet line at the bottom for today's totals and the way to
/// Sessions and Settings.
struct MainView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var notifier: Notifier
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var showTiming = false

    /// The window is this size and can't be resized.
    static let windowSize = CGSize(width: 480, height: 600)
    /// Space between the window's edges and anything along them.
    static let margin: CGFloat = 28

    var body: some View {
        Themed(settings.theme) { theme in
            content(theme: theme)
        }
    }

    private func content(theme: AppTheme) -> some View {
        let accent = theme.accent(for: engine.displayPhase)

        return VStack(spacing: 0) {
            header(theme: theme)

            Spacer(minLength: 8)

            TimerDial(
                countdown: engine.countdown,
                theme: theme, accent: accent,
                ringColors: theme.ringColors(for: engine.displayPhase),
                phase: engine.phase,
                rounds: engine.plan.rounds, round: engine.round,
                repeats: engine.plan.repeatForever,
                next: engine.upNext.map { "Next: \($0)" },
                summary: engine.sessionSummary,
                roundText: engine.roundText
            )
            .anchorPreference(key: DialBoundsKey.self, value: .bounds) { $0 }

            sessionRow(theme: theme)
                .padding(.top, 20)

            controls(theme: theme, accent: accent)
                .padding(.top, 22)

            spaceHint(theme: theme)
                .padding(.top, 10)

            Spacer(minLength: 8)

            footer(theme: theme)
        }
        .ignoresSafeArea(edges: .top)
        .padding(.top, 6)
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        // The glow sits behind the dial wherever the layout puts it.
        .backgroundPreferenceValue(DialBoundsKey.self) { anchor in
            GeometryReader { proxy in
                if let anchor {
                    let rect = proxy[anchor]
                    let glow = theme.isGradient ? (theme.ringColors(for: engine.displayPhase).dropFirst().first ?? accent) : accent
                    RadialGradient(
                        colors: [glow.opacity(theme.isDark ? 0.24 : 0.14), glow.opacity(0)],
                        center: UnitPoint(x: rect.midX / max(proxy.size.width, 1),
                                          y: rect.midY / max(proxy.size.height, 1)),
                        startRadius: 20, endRadius: 300
                    )
                    .animation(.easeInOut(duration: 0.8), value: glow)
                }
            }
        }
        .background(GlassBackground(theme: theme, breakTint: engine.phase.isBreak ? theme.rest : nil))
        .background(WindowConfigurator(theme: theme, floats: settings.floatOnTop))
        .background(CountdownVisibility(countdown: engine.countdown))
        .preferredColorScheme(theme.colorScheme)
        .tint(accent)
        .animation(.easeInOut(duration: 0.35), value: engine.phase)
        .onChange(of: store.selected) { _, new in
            engine.load(new)
        }
        .task { await notifier.requestIfNeeded() }
    }

    // MARK: Header and footer

    private func header(theme: AppTheme) -> some View {
        Text("Tiempo Pomo")
            .font(.system(size: 15, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(theme.text.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .padding(.top, 2)
            .overlay(alignment: .trailing) {
                Button {
                    if settings.showMiniTimer { dismissWindow(id: "mini") } else { openWindow(id: "mini") }
                } label: {
                    Image(systemName: settings.showMiniTimer ? "pip.exit" : "pip.enter")
                }
                .buttonStyle(FooterButtonStyle(theme: theme))
                .help(settings.showMiniTimer ? "Hide the mini timer" : "Mini timer: a small window that stays on top")
                .accessibilityLabel(settings.showMiniTimer ? "Hide mini timer" : "Show mini timer")
                .padding(.trailing, Self.margin - FooterButtonStyle.horizontalPadding)
                .padding(.top, 2)
            }
    }

    private func footer(theme: AppTheme) -> some View {
        HStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max")
                Text("Today  \(Format.minutes(engine.todayFocusMinutes)) · \(engine.todayRounds) round\(engine.todayRounds == 1 ? "" : "s")")
                    .monospacedDigit()
            }
            .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today: \(Format.minutes(engine.todayFocusMinutes)) focused, \(engine.todayRounds) rounds")

            Spacer()

            Button { open(.sessions) } label: { Image(systemName: "square.stack.3d.up") }
                .help("Sessions")
                .accessibilityLabel("Sessions")
            Button { open(.general) } label: { Image(systemName: "gearshape") }
                .help("Settings  ⌘,")
                .accessibilityLabel("Settings")
        }
        .buttonStyle(FooterButtonStyle(theme: theme))
        .padding(.leading, Self.margin)
        .padding(.trailing, Self.margin - FooterButtonStyle.horizontalPadding)
        .padding(.bottom, 20)
    }

    private func open(_ tab: AppSettings.SettingsTab) {
        settings.settingsTab = tab
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Session and timing

    private func sessionRow(theme: AppTheme) -> some View {
        let plan = engine.plan
        let locked = !engine.isIdle
        return HStack(spacing: 8) {
            Menu {
                ForEach(store.presets) { preset in
                    Button {
                        store.selectedID = preset.id
                        engine.load(preset)
                    } label: {
                        Label(preset.name, systemImage: preset.id == store.selectedID ? "checkmark" : preset.symbol)
                    }
                }
                Divider()
                Button("Edit Sessions…") { open(.sessions) }
            } label: {
                PillLabel(theme: theme) {
                    Image(systemName: plan.symbol)
                    Text(engine.isCustomized ? "\(plan.name) (edited)" : plan.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .opacity(0.7)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .focusEffectDisabled()
            .fixedSize()
            .accessibilityLabel("Session: \(plan.name)")

            Button {
                showTiming = true
            } label: {
                PillLabel(theme: theme) {
                    Text("\(plan.focusMinutes) / \(plan.breakMinutes) min")
                        .monospacedDigit()
                    Text(plan.repeatForever ? "· ∞" : "· ×\(plan.rounds)")
                        .opacity(0.75)
                }
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .popover(isPresented: $showTiming, arrowEdge: .bottom) {
                AdjustSessionView()
            }
            .help("Change focus, break and rounds for this run")
            .accessibilityLabel("Timing: \(plan.focusMinutes) minutes focus, \(plan.breakMinutes) minutes break, \(plan.repeatForever ? "repeating" : "\(plan.rounds) rounds"). Edit")
        }
        .disabled(locked)
        .help(locked ? "Reset the timer to change the session" : "")
    }

    // MARK: Controls

    @ViewBuilder
    private func controls(theme: AppTheme, accent: Color) -> some View {
        HStack(spacing: 14) {
            if !engine.isIdle {
                Button(action: engine.reset) { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(CircleIconButtonStyle(theme: theme))
                    .help("Reset  ⌘R")
                    .accessibilityLabel("Reset")
                    .transition(.scale.combined(with: .opacity))
            }

            Button(action: engine.toggle) {
                Text(mainButtonTitle)
                    .frame(minWidth: 120)
            }
            .buttonStyle(AccentButtonStyle(theme: theme, fill: theme.buttonFill(for: engine.displayPhase)))
            .keyboardShortcut(.space, modifiers: [])

            if !engine.isIdle {
                Button(action: engine.skip) { Image(systemName: "forward.end") }
                    .buttonStyle(CircleIconButtonStyle(theme: theme))
                    .help(engine.phase.isBreak ? "Skip break  ⌘→" : "Skip to break  ⌘→")
                    .accessibilityLabel(engine.phase.isBreak ? "Skip break" : "Skip to break")
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: engine.isIdle)
    }

    private func spaceHint(theme: AppTheme) -> some View {
        HStack(spacing: 5) {
            Text("Space")
                .font(.system(size: 10, weight: .semibold, design: theme.fontDesign))
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 4).stroke(theme.secondary.opacity(0.6)))
            Text(engine.isRunning ? "to pause" : "to start")
                .font(.system(size: 11, design: theme.fontDesign))
        }
        .foregroundStyle(theme.secondary)
        .accessibilityHidden(true)
    }

    private var mainButtonTitle: String {
        switch engine.phase {
        case .idle: return "Start"
        case .complete: return "Start Again"
        default:
            if engine.isRunning { return "Pause" }
            // Paused by hand, or waiting because auto-start is off.
            return engine.phaseStarted ? "Resume" : "Start \(engine.phase.label)"
        }
    }
}

private struct DialBoundsKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
