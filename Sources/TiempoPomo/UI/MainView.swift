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

    var body: some View {
        Themed(settings.palette) { theme in
            content(theme: theme)
        }
    }

    private func content(theme: AppTheme) -> some View {
        VStack(spacing: 0) {
            header(theme: theme)
            Spacer(minLength: Space.s)
            TimerDial(countdown: engine.countdown, theme: theme)
                .anchorPreference(key: DialBoundsKey.self, value: .bounds) { $0 }
            HStack(spacing: Space.s) {
                SessionMenu(theme: theme) { open(.sessions) }
                timingButton(theme: theme)
            }
            .padding(.top, Space.xl)
            TimerControls(theme: theme, spaceStartsAndPauses: true)
                .padding(.top, Space.xl)
            spaceHint(theme: theme)
                .padding(.top, Space.s + Space.xxs)
            Spacer(minLength: Space.s)
            footer(theme: theme)
        }
        .ignoresSafeArea(edges: .top)
        .padding(.top, Space.s - 2)
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .backgroundPreferenceValue(DialBoundsKey.self) { anchor in
            DialGlow(anchor: anchor, color: theme.colors(for: engine.displayPhase).glow, isDark: theme.isDark)
        }
        .background(GlassBackground(theme: theme, surface: .window, phase: engine.phase))
        .background(WindowBridge(
            style: .init(isDark: theme.isDark, chrome: .hiddenTitle, floats: settings.floatOnTop,
                         background: NSColor(theme.tint)),
            countdown: engine.countdown))
        .preferredColorScheme(theme.colorScheme)
        .tint(theme.colors(for: engine.displayPhase).shape)
        .animation(.easeInOut(duration: 0.35), value: engine.phase)
        .onChange(of: store.selected) { _, new in engine.load(new) }
        .task { await notifier.requestIfNeeded() }
    }

    // MARK: Header and footer

    private func header(theme: AppTheme) -> some View {
        Text("Tiempo Pomo")
            .textRole(.headline, theme)
            .foregroundStyle(theme.text.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: Space.xxl)
            .padding(.top, Space.xxs)
            .overlay(alignment: .trailing) {
                Button {
                    if settings.showMiniTimer { dismissWindow(id: "mini") } else { openWindow(id: "mini") }
                } label: {
                    Image(systemName: settings.showMiniTimer ? "pip.exit" : "pip.enter")
                }
                .buttonStyle(QuietButtonStyle(theme: theme))
                .help(settings.showMiniTimer ? "Hide the mini timer" : "Mini timer: a small window that stays on top")
                .accessibilityLabel(settings.showMiniTimer ? "Hide mini timer" : "Show mini timer")
                .padding(.trailing, Space.xxl - QuietButtonStyle.horizontalPadding)
                .padding(.top, Space.xxs)
            }
    }

    private func footer(theme: AppTheme) -> some View {
        HStack(spacing: Space.xs) {
            Label("Today  \(Format.minutes(engine.todayFocusMinutes)) · \(engine.todayRounds) round\(engine.todayRounds == 1 ? "" : "s")",
                  systemImage: "sun.max")
                .textRole(.caption, theme)
                .monospacedDigit()
                .foregroundStyle(theme.secondary)
                .accessibilityLabel("Today: \(Format.minutes(engine.todayFocusMinutes)) focused, \(engine.todayRounds) rounds")
            Spacer()
            Button { open(.sessions) } label: { Image(systemName: "square.stack.3d.up") }
                .help("Sessions")
                .accessibilityLabel("Sessions")
            Button { open(.general) } label: { Image(systemName: "gearshape") }
                .help("Settings  ⌘,")
                .accessibilityLabel("Settings")
        }
        .buttonStyle(QuietButtonStyle(theme: theme))
        .padding(.leading, Space.xxl)
        .padding(.trailing, Space.xxl - QuietButtonStyle.horizontalPadding)
        .padding(.bottom, Space.xl)
    }

    private func open(_ tab: AppSettings.SettingsTab) {
        settings.settingsTab = tab
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Timing and the Space hint

    private func timingButton(theme: AppTheme) -> some View {
        let plan = engine.plan
        return Button {
            showTiming = true
        } label: {
            PillLabel(theme: theme) {
                Text("\(plan.focusMinutes) / \(plan.breakMinutes) min").monospacedDigit()
                Text(plan.repeatForever ? "· ∞" : "· ×\(plan.rounds)").opacity(0.75)
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .popover(isPresented: $showTiming, arrowEdge: .bottom) { AdjustSessionView() }
        .disabled(!engine.isIdle)
        .help(engine.isIdle ? "Change focus, break and rounds for this run" : "Reset the timer to change the timing")
        .accessibilityLabel("Timing: \(plan.focusMinutes) minutes focus, \(plan.breakMinutes) minutes break, \(plan.repeatForever ? "repeating" : "\(plan.rounds) rounds"). Edit")
    }

    private func spaceHint(theme: AppTheme) -> some View {
        HStack(spacing: Space.xs + 1) {
            Text("Space")
                .textRole(.keycap, theme)
                .padding(.horizontal, Space.xs + 1)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: Radius.small - 2).stroke(theme.secondary.opacity(0.6)))
            Text(engine.isRunning ? "to pause" : "to start")
                .textRole(.small, theme)
        }
        .foregroundStyle(theme.secondary)
        .accessibilityHidden(true)
    }
}

/// The soft light behind the dial, wherever the layout puts it.
private struct DialGlow: View {
    let anchor: Anchor<CGRect>?
    let color: Color
    let isDark: Bool

    var body: some View {
        GeometryReader { proxy in
            if let anchor {
                let rect = proxy[anchor]
                RadialGradient(
                    colors: [color.opacity(isDark ? 0.24 : 0.14), color.opacity(0)],
                    center: UnitPoint(x: rect.midX / max(proxy.size.width, 1),
                                      y: rect.midY / max(proxy.size.height, 1)),
                    startRadius: 20, endRadius: 300
                )
                .animation(.easeInOut(duration: 0.8), value: color)
            }
        }
    }
}

private struct DialBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
