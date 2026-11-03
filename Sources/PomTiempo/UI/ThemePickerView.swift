import SwiftUI

/// "App Colors": pick one of the glass palettes.
struct ThemePickerView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let theme = settings.theme
        VStack(alignment: .leading, spacing: 16) {
            Text("App Colors")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text("Glass palettes from Glassine, plus Vivid (macOS system colours) and Claude (Anthropic's palette). The ring shows focus colours; the short arc shows breaks.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 12) {
                ForEach(AppTheme.all) { option in
                    ThemeSwatch(theme: option, selected: option.id == settings.themeID)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) { settings.themeID = option.id }
                        }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 600)
        .themedPane(theme)
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme
    let selected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().inset(by: 3).stroke(theme.text.opacity(0.1), lineWidth: 5)
                Circle()
                    .inset(by: 3)
                    .trim(from: 0, to: 0.68)
                    .stroke(AngularGradient(colors: theme.ringColors(for: .focus), center: .center,
                                            startAngle: .degrees(0), endAngle: .degrees(theme.isGradient ? 360 : 245)),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .inset(by: 3)
                    .trim(from: 0.74, to: 0.94)
                    .stroke(AngularGradient(colors: theme.ringColors(for: .shortBreak), center: .center),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("25:00")
                    .font(.system(size: 12, weight: .medium, design: theme.fontDesign))
                    .monospacedDigit()
                    .foregroundStyle(theme.text)
            }
            .frame(width: 64, height: 64)

            HStack(spacing: 5) {
                Text(theme.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.text)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.focus)
                }
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(
                        colors: [theme.tintColor, theme.tintColor.opacity(0.85)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                if let blooms = theme.backdrop {
                    LinearGradient(colors: blooms.map { Color(hex: $0).opacity(0.35) },
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? theme.focus : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 1)
        )
        .contentShape(Rectangle())
    }
}
