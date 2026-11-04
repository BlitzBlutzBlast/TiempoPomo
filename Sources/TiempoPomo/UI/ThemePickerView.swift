import SwiftUI

/// Settings › Appearance: pick a palette.
struct ThemePickerView: View {
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text("Glass palettes from Glassine, plus Vivid (macOS system colours) and Claude (Anthropic's palette). The ring shows focus colours; the short arc shows breaks.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 12) {
                ForEach(Palette.all) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { settings.themeID = option.id }
                    } label: {
                        ThemeSwatch(theme: AppTheme.resolve(option), selected: option.id == settings.themeID)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.name) palette")
                    .accessibilityAddTraits(option.id == settings.themeID ? .isSelected : [])
                }
            }

            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme
    let selected: Bool

    var body: some View {
        let focus = theme.colors(for: .focus)
        let rest = theme.colors(for: .shortBreak)
        VStack(spacing: Space.s + Space.xxs) {
            ZStack {
                ProgressRing(fraction: 0.68, colors: focus, lineWidth: 5, track: theme.track)
                ProgressRing(fraction: 0.2, colors: rest, lineWidth: 5)
                    .rotationEffect(.degrees(0.74 * 360))
                Text("25:00")
                    .textRole(.caption, theme)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundStyle(theme.text)
            }
            .padding(3)
            .frame(width: 64, height: 64)

            HStack(spacing: Space.xs + 1) {
                Text(theme.name)
                    .font(TextRole.label.font(theme.fontDesign))
                    .foregroundStyle(theme.text)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(focus.shape)
                }
            }
        }
        .padding(.vertical, Space.m + 2)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                theme.tint
                if let blooms = theme.blooms {
                    LinearGradient(colors: blooms.map { $0.opacity(0.35) },
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .stroke(selected ? focus.shape : theme.stroke, lineWidth: selected ? 2 : 1)
        )
        .contentShape(Rectangle())
    }
}
