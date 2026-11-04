import SwiftUI

/// The countdown ring and time. It watches only `Countdown`, so each second
/// redraws this view alone. The ring is a plain arc that steps once a second:
/// on a 25-minute round each step is a fraction of a degree, so it reads as
/// a smooth drain without any animation.
struct TimerDial: View {
    @ObservedObject var countdown: Countdown
    let theme: AppTheme
    let accent: Color
    let ringColors: [Color]
    let phase: Phase
    let rounds: Int
    let round: Int
    let repeats: Bool
    /// "Next: Break · 10 min" while a session is under way.
    let next: String?
    /// "4 rounds · 2h 40m focused" when the session is done.
    let summary: String
    /// Spoken by VoiceOver, e.g. "Round 2 of 4".
    let roundText: String

    static let size: CGFloat = 260
    private let lineWidth: CGFloat = 10
    /// Space between the ring and the dial's edge, so the glow isn't clipped.
    private let inset: CGFloat = 10

    var body: some View {
        ZStack {
            if phase == .complete {
                FinishRing(color: accent, lineWidth: lineWidth, inset: inset)
                finished
            } else {
                ring
                running
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var running: some View {
        VStack(spacing: 10) {
            Label(phase.label.uppercased(), systemImage: phase.symbol)
                .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                .tracking(1.4)
                .foregroundStyle(theme.accentText(for: phase == .idle ? .focus : phase))
            Text(Format.clock(TimeInterval(countdown.seconds)))
                .font(.system(size: 60, weight: .light, design: theme.fontDesign))
                .monospacedDigit()
                .foregroundStyle(theme.text)
            // Dots only when there's more than one round to count.
            if repeats || rounds > 1 {
                RoundDots(theme: theme, accent: accent, total: rounds, current: round,
                          repeats: repeats, done: false)
            }
            if let next {
                Text(next)
                    .font(.system(size: 11.5, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.secondary)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30))
                .foregroundStyle(theme.accentShape(for: .complete))
            Text("Session complete")
                .font(.system(size: 20, weight: .semibold, design: theme.fontDesign))
                .foregroundStyle(theme.text)
            Text(summary)
                .font(.system(size: 12.5, design: theme.fontDesign))
                .foregroundStyle(theme.secondary)
        }
    }

    private var accessibilityText: String {
        if phase == .complete { return "Session complete. \(summary)" }
        let m = countdown.seconds / 60, s = countdown.seconds % 60
        var parts = ["\(phase.label), \(m) minute\(m == 1 ? "" : "s") \(s) second\(s == 1 ? "" : "s") left"]
        if rounds > 1 || repeats { parts.append(roundText) }
        if let next { parts.append(next) }
        return parts.joined(separator: ". ")
    }

    private var ring: some View {
        let left = countdown.fraction
        let radius = Self.size / 2 - inset - lineWidth / 2
        // Gap between the arc's end and the track, allowing for both round caps.
        let gap = Double((lineWidth + 8) / (2 * .pi * radius))
        let gradient = ringColors.count > 2
            ? AngularGradient(colors: ringColors, center: .center)
            : AngularGradient(colors: ringColors, center: .center,
                              startAngle: .degrees(0), endAngle: .degrees(360 * max(left, 0.01)))
        return ZStack {
            if left < 1 - gap * 2 {
                Circle()
                    .inset(by: inset + lineWidth / 2)
                    .trim(from: left + gap, to: 1 - gap)
                    .stroke(theme.text.opacity(theme.highContrast ? 0.3 : (theme.isDark ? 0.12 : 0.10)),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            Circle()
                .inset(by: inset + lineWidth / 2)
                .trim(from: 0, to: left)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .shadow(color: (ringColors.dropFirst().first ?? accent).opacity(0.5), radius: 8)
        }
        .rotationEffect(.degrees(-90))
        // Draw on the GPU: CoreGraphics would otherwise work out the
        // gradient pixel by pixel on the CPU every second.
        .drawingGroup()
    }
}

/// The finished session's ring: sweeps closed once in the "done" colour,
/// then stays still.
private struct FinishRing: View {
    let color: Color
    let lineWidth: CGFloat
    let inset: CGFloat
    @State private var sweep: Double = 0

    var body: some View {
        Circle()
            .inset(by: inset + lineWidth / 2)
            .trim(from: 0, to: sweep)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .shadow(color: color.opacity(0.5), radius: 8)
            .rotationEffect(.degrees(-90))
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) { sweep = 1 }
            }
    }
}

struct RoundDots: View {
    let theme: AppTheme
    let accent: Color
    let total: Int
    let current: Int
    let repeats: Bool
    let done: Bool

    var body: some View {
        HStack(spacing: 6) {
            if repeats {
                Image(systemName: "infinity")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
            } else {
                ForEach(1...max(1, min(total, 12)), id: \.self) { i in
                    Circle()
                        .fill(fill(for: i))
                        .frame(width: 7, height: 7)
                }
            }
        }
        .frame(height: 10)
    }

    private func fill(for i: Int) -> Color {
        if done || i < current { return accent }
        if i == current { return accent.opacity(0.45) }
        return theme.text.opacity(0.15)
    }
}

/// A rounded glass card.
struct Card<Content: View>: View {
    let theme: AppTheme
    @ViewBuilder var content: Content

    var body: some View {
        // Content starts at the top-left and the card fills whatever size it
        // is given, so cards side by side line up edge to edge.
        VStack(alignment: .leading, spacing: 8) { content }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.stroke, lineWidth: 1))
            )
    }
}

struct CardHeading: View {
    let theme: AppTheme
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold, design: theme.fontDesign))
            .tracking(1.4)
            .foregroundStyle(theme.secondary)
    }
}

/// The main "Start Timer" capsule.
struct AccentButtonStyle: ButtonStyle {
    let theme: AppTheme
    /// Colours and a label colour checked for contrast; see `AppTheme.buttonFill`.
    let fill: ButtonFill

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: theme.fontDesign))
            .foregroundStyle(fill.label)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(LinearGradient(colors: fill.stops,
                                              startPoint: fill.stops.count > 2 ? .leading : .top,
                                              endPoint: fill.stops.count > 2 ? .trailing : .bottom))
            )
            .shadow(color: fill.glow.opacity(configuration.isPressed ? 0.2 : 0.45), radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Small round icon buttons beside the main one (reset, skip).
struct CircleIconButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.text.opacity(0.85))
            .frame(width: 40, height: 40)
            .background(Circle().fill(theme.surface).overlay(Circle().stroke(theme.stroke)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

/// The quiet text buttons along the bottom of the window.
struct FooterButtonStyle: ButtonStyle {
    static let horizontalPadding: CGFloat = 12
    let theme: AppTheme
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.text.opacity(hovering ? 1 : 0.72))
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, 7)
            .background(Capsule().fill(hovering || configuration.isPressed ? theme.surface : .clear))
            .onHover { hovering = $0 }
    }
}

/// A rounded, quiet button for the session and timing under the dial.
struct PillLabel<Content: View>: View {
    let theme: AppTheme
    @ViewBuilder var content: Content
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 6) { content }
            .font(.system(size: 12.5, weight: .medium, design: theme.fontDesign))
            .foregroundStyle(theme.text.opacity(isEnabled ? 0.92 : 0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(hovering && isEnabled ? theme.surface.opacity(2) : theme.surface)
                    .overlay(Capsule().stroke(theme.stroke))
            )
            .contentShape(Capsule())
            .onHover { hovering = $0 }
    }
}
