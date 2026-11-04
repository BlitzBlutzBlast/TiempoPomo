import SwiftUI

// The pieces every timer surface is built from. The main window, the menu
// bar popover and the mini timer use these same components, so a change to
// how the time, the ring, the controls or the session picker look or behave
// is made once.

// MARK: - Time and progress

/// The countdown digits. Only this redraws each second.
struct CountdownText: View {
    @ObservedObject var countdown: Countdown
    let role: TextRole
    let theme: AppTheme

    var body: some View {
        Text(Format.clock(TimeInterval(countdown.seconds)))
            .textRole(role, theme)
            .monospacedDigit()
            .foregroundStyle(theme.text)
    }
}

/// The phase name in tracked capitals, in the phase's accent.
struct PhaseLabel: View {
    let phase: Phase
    let theme: AppTheme

    var body: some View {
        Label(phase.label.uppercased(), systemImage: phase.symbol)
            .textRole(.label, theme)
            .foregroundStyle(theme.colors(for: phase).text)
    }
}

/// A ring that drains clockwise from 12 o'clock. With `track`, the used-up
/// part is drawn thin and quiet; with `gapped`, the two ends stay apart.
struct ProgressRing: View {
    let fraction: Double
    let colors: MoodColors
    let lineWidth: CGFloat
    var track: Color? = nil
    var gapped = false
    var glows = false
    /// Room inside the frame, so a glow isn't clipped at its edge.
    var margin: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2 - margin - lineWidth / 2
            // Gap between the arc's end and the track, allowing for both round caps.
            let gap = gapped ? Double((lineWidth + 8) / (2 * .pi * max(radius, 1))) : 0
            let left = max(0, min(1, fraction))
            ZStack {
                if let track, left < 1 - gap * 2 {
                    Circle()
                        .inset(by: margin + lineWidth / 2)
                        .trim(from: left + gap, to: 1 - gap)
                        .stroke(track, style: StrokeStyle(lineWidth: gapped ? lineWidth * 0.4 : lineWidth, lineCap: .round))
                }
                Circle()
                    .inset(by: margin + lineWidth / 2)
                    .trim(from: 0, to: left)
                    .stroke(gradient(left), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .shadow(color: glows ? colors.glow.opacity(0.5) : .clear, radius: 8)
            }
            .rotationEffect(.degrees(-90))
        }
        // Drawn on the GPU: CoreGraphics would otherwise work out the
        // gradient pixel by pixel on the CPU every time it changes.
        .drawingGroup()
    }

    private func gradient(_ left: Double) -> AngularGradient {
        colors.ringIsGradient
            ? AngularGradient(colors: colors.ring, center: .center)
            : AngularGradient(colors: colors.ring, center: .center,
                              startAngle: .degrees(0), endAngle: .degrees(360 * max(left, 0.01)))
    }
}

/// A thin bar that drains left to right, for the popover.
struct ProgressBar: View {
    @ObservedObject var countdown: Countdown
    let color: Color
    let track: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: max(4, proxy.size.width * countdown.fraction))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

// MARK: - The dial

/// The main window's dial: the ring, the phase, the time, the rounds and
/// what comes next; or, once a session is done, its summary.
struct TimerDial: View {
    @EnvironmentObject private var engine: TimerEngine
    @ObservedObject var countdown: Countdown
    let theme: AppTheme

    static let size: CGFloat = 260
    private let lineWidth: CGFloat = 10
    /// Room between the ring and the dial's edge, so the glow isn't clipped.
    private let inset: CGFloat = 10

    var body: some View {
        let colors = theme.colors(for: engine.displayPhase)
        ZStack {
            if engine.phase == .complete {
                FinishRing(color: colors.shape, lineWidth: lineWidth)
                    .padding(inset)
                finished
            } else {
                ProgressRing(fraction: countdown.fraction, colors: colors, lineWidth: lineWidth,
                             track: theme.track, gapped: true, glows: true, margin: inset)
                running
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var running: some View {
        VStack(spacing: Space.s + Space.xxs) {
            PhaseLabel(phase: engine.phase, theme: theme)
            CountdownText(countdown: countdown, role: .dialTime, theme: theme)
            if engine.showsRounds {
                RoundDots(color: theme.colors(for: engine.displayPhase).shape, empty: theme.track,
                          total: engine.plan.rounds, current: engine.round, repeats: engine.plan.repeatForever)
            }
            if let next = engine.upNext {
                Text("Next: \(next)")
                    .textRole(.caption, theme)
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: Space.s) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(theme.colors(for: .complete).shape)
            Text("Session complete")
                .textRole(.title, theme)
                .foregroundStyle(theme.text)
            Text(engine.sessionSummary)
                .textRole(.caption, theme)
                .foregroundStyle(theme.secondary)
        }
    }

    private var accessibilityText: String {
        if engine.phase == .complete { return "Session complete. \(engine.sessionSummary)" }
        let m = countdown.seconds / 60, s = countdown.seconds % 60
        var parts = ["\(engine.phase.label), \(m) minute\(m == 1 ? "" : "s") \(s) second\(s == 1 ? "" : "s") left"]
        if engine.showsRounds { parts.append(engine.roundText) }
        if let next = engine.upNext { parts.append("Next: \(next)") }
        return parts.joined(separator: ". ")
    }
}

/// A finished session's ring: sweeps closed once, then stays still.
private struct FinishRing: View {
    let color: Color
    let lineWidth: CGFloat
    @State private var sweep: Double = 0

    var body: some View {
        Circle()
            .inset(by: lineWidth / 2)
            .trim(from: 0, to: sweep)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .shadow(color: color.opacity(0.5), radius: 8)
            .rotationEffect(.degrees(-90))
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { sweep = 1 }
            }
    }
}

/// One dot per round: filled when done, half-filled for the current one.
struct RoundDots: View {
    let color: Color
    let empty: Color
    let total: Int
    let current: Int
    let repeats: Bool

    var body: some View {
        HStack(spacing: Space.s - 2) {
            if repeats {
                Image(systemName: "infinity")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
            } else {
                ForEach(1...max(1, min(total, 12)), id: \.self) { i in
                    Circle()
                        .fill(i < current ? color : (i == current ? color.opacity(0.45) : empty))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(height: 10)
    }
}

// MARK: - Controls

/// Reset, Start/Pause, Skip: the same row, the same titles and the same
/// layout on every surface. Reset and Skip are always laid out and only
/// enabled while a session runs, so nothing shifts when it starts.
struct TimerControls: View {
    @EnvironmentObject private var engine: TimerEngine
    let theme: AppTheme
    /// The main button stretches to fill the row (the popover).
    var fillsWidth = false
    /// Space starts and pauses (the main window).
    var spaceStartsAndPauses = false

    var body: some View {
        HStack(spacing: fillsWidth ? Space.s + Space.xxs : Space.m) {
            Button(action: engine.reset) { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(CircleIconButtonStyle(theme: theme))
                .help("Reset  ⌘R")
                .accessibilityLabel("Reset")
                .disabled(engine.isIdle)
                .opacity(engine.isIdle ? 0.4 : 1)

            Button(action: engine.toggle) {
                Text(engine.primaryActionTitle)
                    .lineLimit(1)
                    // The popover's row is narrow: the button takes what's left
                    // between the round buttons rather than a fixed minimum.
                    .frame(minWidth: fillsWidth ? 0 : 120, maxWidth: fillsWidth ? .infinity : nil)
            }
            .buttonStyle(AccentButtonStyle(theme: theme, fill: theme.colors(for: engine.displayPhase).button,
                                           horizontalPadding: fillsWidth ? Space.l : Space.xxl))
            .focusEffectDisabled()
            .modifier(SpaceShortcut(enabled: spaceStartsAndPauses))

            Button(action: engine.skip) { Image(systemName: "forward.end") }
                .buttonStyle(CircleIconButtonStyle(theme: theme))
                .help("\(engine.skipTitle)  ⌘→")
                .accessibilityLabel(engine.skipTitle)
                .disabled(engine.isIdle)
                .opacity(engine.isIdle ? 0.4 : 1)
        }
    }
}

private struct SpaceShortcut: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled { content.keyboardShortcut(.space, modifiers: []) } else { content }
    }
}

/// The session picker: a pill with the session's icon and name. Disabled
/// while a session runs.
struct SessionMenu: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var store: PresetStore
    let theme: AppTheme
    /// Stretch to fill the row, with the chevron at the far end.
    var fillsWidth = false
    /// Adds "Edit Sessions…" at the bottom of the menu.
    var editSessions: (() -> Void)? = nil

    var body: some View {
        let plan = engine.plan
        Menu {
            ForEach(store.presets) { preset in
                Button {
                    store.selectedID = preset.id
                    engine.load(preset)
                } label: {
                    Label(preset.name, systemImage: preset.id == store.selectedID ? "checkmark" : preset.symbol)
                }
            }
            if let editSessions {
                Divider()
                Button("Edit Sessions…", action: editSessions)
            }
        } label: {
            PillLabel(theme: theme) {
                Image(systemName: plan.symbol)
                Text(engine.isCustomized ? "\(plan.name) (edited)" : plan.name)
                    .lineLimit(1)
                if fillsWidth { Spacer(minLength: Space.xs) }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .opacity(0.7)
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .focusEffectDisabled()
        .fixedSize(horizontal: !fillsWidth, vertical: true)
        .disabled(!engine.isIdle)
        .help(engine.isIdle ? "" : "Reset the timer to change the session")
        .accessibilityLabel("Session: \(plan.name)")
    }
}

// MARK: - Button styles

/// The Start/Pause capsule, in the phase's contrast-checked colours.
struct AccentButtonStyle: ButtonStyle {
    let theme: AppTheme
    let fill: ButtonFill
    var horizontalPadding: CGFloat = Space.xxl

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textRole(.headline, theme)
            .foregroundStyle(fill.label)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, Space.m)
            .background(
                Capsule().fill(LinearGradient(colors: fill.stops,
                                              startPoint: fill.stops.count > 2 ? .leading : .top,
                                              endPoint: fill.stops.count > 2 ? .trailing : .bottom))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The round Reset and Skip buttons.
struct CircleIconButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.text.opacity(0.85))
            .frame(width: 40, height: 40)
            .background(Circle().fill(configuration.isPressed ? theme.surfaceHover : theme.surface)
                .overlay(Circle().stroke(theme.stroke)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

/// Quiet buttons that only show a fill on hover: icon buttons along the
/// window's edges (capsule), and the popover's rows (row).
struct QuietButtonStyle: ButtonStyle {
    enum Shape { case capsule, row }

    static let horizontalPadding: CGFloat = Space.m
    static let rowPadding: CGFloat = Space.s + Space.xxs

    let theme: AppTheme
    var shape: Shape = .capsule
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        let lit = hovering || configuration.isPressed
        let label = configuration.label
            .textRole(shape == .row ? .body : .control, theme)
            .foregroundStyle(shape == .row ? theme.text : theme.text.opacity(lit ? 1 : 0.72))
            .onHover { hovering = $0 }
        switch shape {
        case .capsule:
            label
                .padding(.horizontal, Self.horizontalPadding)
                .padding(.vertical, Space.s - 1)
                .background(Capsule().fill(lit ? theme.surface : .clear))
        case .row:
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.s - 1)
                .padding(.horizontal, Self.rowPadding)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(lit ? theme.surface : .clear))
        }
    }
}

/// A rounded, quiet pill: the session picker and the timing button.
struct PillLabel<Content: View>: View {
    let theme: AppTheme
    @ViewBuilder var content: Content
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: Space.s - 2) { content }
            .textRole(.control, theme)
            .foregroundStyle(theme.text.opacity(isEnabled ? 0.92 : 0.6))
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s - 1)
            .background(
                Capsule().fill(hovering && isEnabled ? theme.surfaceHover : theme.surface)
                    .overlay(Capsule().stroke(theme.stroke))
            )
            .contentShape(Capsule())
            .onHover { hovering = $0 }
    }
}
