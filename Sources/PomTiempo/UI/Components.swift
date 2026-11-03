import SwiftUI

/// The countdown ring. It starts full and drains as the phase runs down.
/// While the timer runs, the ring ripples into a wave that flows around it;
/// when it stops, the wave settles back into a smooth line.
struct TimerDial: View {
    let theme: AppTheme
    let accent: Color
    let ringColors: [Color]
    /// Fraction of the phase left at a given moment, read every frame so the
    /// ring drains continuously rather than in steps.
    let fractionLeft: (Date) -> Double
    let isRunning: Bool
    let time: String
    let phase: Phase
    let roundText: String
    let rounds: Int
    let round: Int
    let repeats: Bool

    static let size: CGFloat = 260
    private let lineWidth: CGFloat = 10
    private let waveHeight: CGFloat = 4.5

    var body: some View {
        ZStack {
            WaveRing(fractionLeft: fractionLeft, isRunning: isRunning,
                     colors: ringColors,
                     glowColor: (ringColors.dropFirst().first ?? accent).opacity(0.5),
                     trackColor: theme.text.opacity(theme.isDark ? 0.12 : 0.10),
                     lineWidth: lineWidth, waveHeight: waveHeight, settleTime: Self.settleTime)

            VStack(spacing: 8) {
                Label(phase.label.uppercased(), systemImage: phase.symbol)
                    .font(.system(size: 12, weight: .semibold, design: theme.fontDesign))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                Text(time)
                    .font(.system(size: 58, weight: .light, design: theme.fontDesign))
                    .monospacedDigit()
                    .foregroundStyle(theme.text)
                    .contentTransition(.numericText(countsDown: true))
                RoundDots(theme: theme, accent: accent, total: rounds, current: round,
                          repeats: repeats, done: phase == .complete)
                Text(roundText)
                    .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                    .foregroundStyle(theme.secondary)
            }
        }
        .frame(width: Self.size, height: Self.size)
    }

    /// How long the wave takes to swell or settle when the timer starts or stops.
    static let settleTime: TimeInterval = 0.7
}

/// An arc from 12 o'clock, clockwise, whose radius ripples as a sine wave.
/// The wave is fixed to the angle around the circle, not to the arc, so it
/// keeps its shape as the arc shortens; `phase` slides it along. Only the
/// wave height animates, so it can swell and settle smoothly.
struct WavyArc: Shape {
    var sweep: Double
    var amplitude: CGFloat
    var phase: Double
    var radius: CGFloat
    /// Number of crests around the full circle.
    var waves: Double = 14

    var animatableData: CGFloat {
        get { amplitude }
        set { amplitude = newValue }
    }

    func path(in rect: CGRect) -> Path {
        Self.path(sweep: sweep, amplitude: amplitude, phase: phase, radius: radius,
                  center: CGPoint(x: rect.midX, y: rect.midY), waves: waves)
    }

    /// `startFraction` starts the arc further round than 12 o'clock.
    static func path(sweep: Double, amplitude: CGFloat, phase: Double, radius: CGFloat,
                     center: CGPoint, waves: Double = 14, startFraction: Double = 0) -> Path {
        var path = Path()
        guard sweep > 0.0005 else { return path }
        let total = min(sweep, 1) * 2 * .pi
        let start = startFraction * 2 * .pi
        let steps = max(12, Int(total / (2 * .pi) * 240))
        // The wave eases in and out over the arc's ends so the caps sit on the line.
        let taper = 0.3
        for i in 0...steps {
            let t = Double(i) / Double(steps) * total
            let k = min(1, min(t, total - t) / taper)
            let ease = k * k * (3 - 2 * k)
            let angle = -Double.pi / 2 + start + t
            let r = Double(radius) + Double(amplitude) * ease * sin(waves * angle - phase)
            let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
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
    let accent: Color
    /// More than two colours: the button carries the palette's gradient.
    var colors: [Color] = []

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: theme.fontDesign))
            .tracking(0.6)
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(colors.count > 2
                    ? LinearGradient(colors: Array(colors.dropLast()), startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [accent, accent.opacity(0.78)], startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: accent.opacity(configuration.isPressed ? 0.2 : 0.45), radius: 12, y: 4)
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
