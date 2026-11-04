import SwiftUI

/// "Change session time": tweak the timings for the next run without
/// touching the saved session, or save them back to it.
struct AdjustSessionView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var engine: TimerEngine
    @Environment(\.dismiss) private var dismiss

    @State private var draft: SessionPreset = .defaultSession
    @State private var loaded = false

    var body: some View {
        let theme = settings.theme
        VStack(alignment: .leading, spacing: 14) {
            Text("Change session time")
                .font(.system(size: 15, weight: .semibold))
            Text("Applies to the next run of \(store.selected.name).")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TimingFields(preset: $draft)

            HStack {
                Button("Revert") {
                    engine.load(store.selected)
                    draft = store.selected
                }
                .disabled(!engine.isCustomized && draft == store.selected)
                Spacer()
                Button("Save to Session") {
                    var saved = draft
                    saved.id = store.selected.id
                    saved.name = store.selected.name
                    saved.symbol = store.selected.symbol
                    store.update(saved)
                    engine.load(saved)
                    dismiss()
                }
                Button("Apply") {
                    engine.customize(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 330)
        .tint(theme.colors(for: .focus).shape)
        .onAppear {
            guard !loaded else { return }
            draft = engine.plan
            loaded = true
        }
    }
}

/// The steppers shared by the popover and the session editor.
struct TimingFields: View {
    @Binding var preset: SessionPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Focus", value: $preset.focusMinutes, range: 1...240, unit: "min")
            row("Break", value: $preset.breakMinutes, range: 1...90, unit: "min")
            row("Rounds", value: $preset.rounds, range: 1...24, unit: "")
                .disabled(preset.repeatForever)
                .opacity(preset.repeatForever ? 0.4 : 1)
            Toggle("Repeat until I stop it", isOn: $preset.repeatForever)
        }
    }

    private func row(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer()
                TextField("", value: value, format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: value.wrappedValue) { _, v in
                        value.wrappedValue = min(max(v, range.lowerBound), range.upperBound)
                    }
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .leading)
            }
        }
    }
}
