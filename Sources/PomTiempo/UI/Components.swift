import SwiftUI

/// The countdown ring. It starts full and drains as the phase runs down.
struct TimerDial: View {
    let theme: AppTheme
    let accent: Color
    let fractionLeft: Double
    let time: String
    let phase: Phase
    let roundText: String
    let rounds: Int
    let round: Int
    let repeats: Bool

    static let size: CGFloat = 260
    private let lineWidth: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.text.opacity(theme.isDark ? 0.08 : 0.07), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fractionLeft)
                .stroke(
                    AngularGradient(colors: [accent.opacity(0.55), accent], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(fractionLeft, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.55), radius: 10)
                .animation(.linear(duration: 0.25), value: fractionLeft)

            VStack(spacing: 8) {
                Label(phase.label.uppercased(), systemImage: phase.symbol)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(accent)
                Text(time)
                    .font(.system(size: 58, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.text)
                    .contentTransition(.numericText(countsDown: true))
                RoundDots(theme: theme, accent: accent, total: rounds, current: round,
                          repeats: repeats, done: phase == .complete)
                Text(roundText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondary)
            }
        }
        .frame(width: Self.size, height: Self.size)
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
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .tracking(1.4)
            .foregroundStyle(theme.secondary)
    }
}

/// The main "Start Timer" capsule.
struct AccentButtonStyle: ButtonStyle {
    let theme: AppTheme
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(LinearGradient(colors: [accent, accent.opacity(0.78)], startPoint: .top, endPoint: .bottom))
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
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(theme.text.opacity(hovering ? 1 : 0.72))
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, 7)
            .background(Capsule().fill(hovering || configuration.isPressed ? theme.surface : .clear))
            .onHover { hovering = $0 }
    }
}
