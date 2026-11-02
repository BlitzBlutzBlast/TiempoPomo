import SwiftUI

struct MainView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var notifier: Notifier

    @State private var sheet: Sheet?
    @State private var showAdjust = false

    enum Sheet: String, Identifiable {
        case presets, colors, settings
        var id: String { rawValue }
    }

    var body: some View {
        let theme = settings.theme
        let accent = theme.accent(for: engine.displayPhase)

        VStack(spacing: 0) {
            Text("PomTiempo")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(theme.text)
                .frame(height: 28)
                .padding(.top, 2)

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 26) {
                TodayCard(theme: theme, accent: accent)
                    .frame(width: 160)

                VStack(spacing: 20) {
                    TimerDial(
                        theme: theme, accent: accent,
                        fractionLeft: engine.fractionLeft,
                        time: Format.clock(engine.remaining),
                        phase: engine.phase,
                        roundText: engine.roundText,
                        rounds: engine.plan.rounds, round: engine.round,
                        repeats: engine.plan.repeatForever
                    )
                    controls(theme: theme, accent: accent)
                    Button {
                        showAdjust = true
                    } label: {
                        Label("Change session time", systemImage: "slider.horizontal.below.rectangle")
                    }
                    .buttonStyle(FooterButtonStyle(theme: theme))
                    .disabled(!engine.isIdle)
                    .opacity(engine.isIdle ? 1 : 0.35)
                    .popover(isPresented: $showAdjust, arrowEdge: .bottom) {
                        AdjustSessionView()
                    }
                }

                SessionCard(theme: theme, accent: accent)
                    .frame(width: 160)
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 16)

            HStack {
                Button { sheet = .presets } label: { Label("Update Defaults", systemImage: "square.stack.3d.up") }
                Spacer()
                Button { sheet = .colors } label: { Label("App Colors", systemImage: "paintpalette") }
                Spacer()
                Button { sheet = .settings } label: { Label("Settings", systemImage: "gearshape") }
            }
            .buttonStyle(FooterButtonStyle(theme: theme))
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .ignoresSafeArea(edges: .top)
        .padding(.top, 6)
        .frame(minWidth: 680, minHeight: 540)
        .background(GlassBackground(theme: theme, glow: accent))
        .background(WindowConfigurator(theme: theme, floats: settings.floatOnTop))
        .preferredColorScheme(theme.colorScheme)
        .tint(accent)
        .animation(.easeInOut(duration: 0.35), value: engine.phase)
        .sheet(item: $sheet) { which in
            switch which {
            case .presets: PresetsEditorView()
            case .colors: ThemePickerView()
            case .settings: SettingsView(showsDone: true)
            }
        }
        .onChange(of: store.selected) { _, new in
            engine.load(new)
        }
        .task { await notifier.requestIfNeeded() }
    }

    @ViewBuilder
    private func controls(theme: AppTheme, accent: Color) -> some View {
        HStack(spacing: 14) {
            if !engine.isIdle {
                Button(action: engine.reset) { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(CircleIconButtonStyle(theme: theme))
                    .help("Reset")
                    .transition(.scale.combined(with: .opacity))
            }

            Button(action: engine.toggle) {
                Text(mainButtonTitle)
                    .frame(minWidth: 128)
            }
            .buttonStyle(AccentButtonStyle(theme: theme, accent: accent))
            .keyboardShortcut(.space, modifiers: [])

            if !engine.isIdle {
                Button(action: engine.skip) { Image(systemName: "forward.end") }
                    .buttonStyle(CircleIconButtonStyle(theme: theme))
                    .help(engine.phase.isBreak ? "Skip break" : "Skip to break")
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: engine.isIdle)
    }

    private var mainButtonTitle: String {
        switch engine.phase {
        case .idle: return "START TIMER"
        case .complete: return "START AGAIN"
        default:
            if engine.isRunning { return "PAUSE" }
            // Paused by hand, or waiting because auto-start is off.
            return engine.remaining < engine.phaseDuration ? "RESUME" : "START \(engine.phase.label.uppercased())"
        }
    }
}

/// Left of the dial: today's totals and what's coming next.
private struct TodayCard: View {
    @EnvironmentObject private var engine: TimerEngine
    let theme: AppTheme
    let accent: Color

    var body: some View {
        Card(theme: theme) {
            CardHeading(theme: theme, text: "Today")
            Text(Format.minutes(engine.todayFocusMinutes))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.text)
            Text("\(engine.todayRounds) focus round\(engine.todayRounds == 1 ? "" : "s")")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(theme.secondary)

            if let next = engine.upNext {
                Divider().overlay(theme.stroke).padding(.vertical, 4)
                CardHeading(theme: theme, text: "Up next")
                Text(next)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.text)
            }
        }
    }
}

/// Right of the dial: the session the timer is set to, with a menu to pick another.
private struct SessionCard: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var store: PresetStore
    let theme: AppTheme
    let accent: Color

    var body: some View {
        let plan = engine.plan
        Card(theme: theme) {
            CardHeading(theme: theme, text: engine.isCustomized ? "Custom session" : "Session")

            Menu {
                ForEach(store.presets) { preset in
                    Button {
                        store.selectedID = preset.id
                        engine.load(preset)
                    } label: {
                        Label(preset.name, systemImage: preset.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: plan.symbol)
                        .foregroundStyle(accent)
                    Text(plan.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if engine.isIdle {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            .disabled(!engine.isIdle)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(plan.focusMinutes)").underline()
                Text("–").foregroundStyle(theme.secondary)
                Text("\(plan.breakMinutes)").underline()
                Text("min")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(theme.secondary)
            }
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.roundsText)
                if plan.hasLongBreak {
                    Text("Long break \(plan.longBreakMinutes) min every \(plan.longBreakEvery)")
                }
                if let total = plan.totalMinutes {
                    Text("Total \(Format.minutes(total))")
                }
            }
            .font(.system(size: 11.5, design: .rounded))
            .foregroundStyle(theme.secondary)
        }
    }
}
