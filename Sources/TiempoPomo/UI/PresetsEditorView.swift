import SwiftUI

/// Settings › Sessions: add, name, edit and remove saved sessions.
struct PresetsEditorView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: PresetStore
    @EnvironmentObject private var engine: TimerEngine

    @State private var selection: UUID?

    var body: some View {
        let theme = settings.theme
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar(theme: theme)
                    .frame(width: 200)
                Divider()
                Group {
                    if let id = selection, let binding = store.binding(for: id) {
                        PresetForm(preset: binding)
                            .id(id)
                    } else {
                        Text("Select a session")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Divider()
            HStack {
                Button("Restore Starting Sessions") { store.restoreBuiltIns() }
                Spacer()
                Button("Use This Session") {
                    if let selection {
                        store.selectedID = selection
                        engine.load(store.selected)
                    }
                }
                .disabled(selection == nil || !engine.isIdle || selection == store.selectedID)
            }
            .padding(14)
        }
        .scrollContentBackground(.hidden)
        .onAppear { selection = store.selectedID }
    }

    private func sidebar(theme: AppTheme) -> some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section("Sessions") {
                    ForEach(store.presets) { preset in
                        HStack {
                            Label(preset.name, systemImage: preset.symbol)
                            Spacer()
                            if preset.id == store.selectedID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(theme.colors(for: .focus).shape)
                            }
                        }
                        .tag(preset.id)
                    }
                    .onMove { store.presets.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            HStack(spacing: 4) {
                Button {
                    selection = store.add().id
                } label: { Image(systemName: "plus") }
                    .help("New session")
                Button {
                    guard let id = selection else { return }
                    let index = store.presets.firstIndex { $0.id == id } ?? 0
                    store.delete(id)
                    selection = store.presets[min(index, store.presets.count - 1)].id
                } label: { Image(systemName: "minus") }
                    .accessibilityLabel("Delete session")
                    .help("Delete session")
                    .disabled(selection == nil || store.presets.count <= 1)
                Button {
                    if let id = selection { selection = store.duplicate(id)?.id }
                } label: { Image(systemName: "plus.square.on.square") }
                    .help("Duplicate session")
                    .disabled(selection == nil)
                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(10)
        }
    }
}

private struct PresetForm: View {
    @Binding var preset: SessionPreset

    var body: some View {
        Form {
            Section("Name") {
                TextField("Session name", text: $preset.name)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 8), alignment: .leading, spacing: 6) {
                    ForEach(SessionPreset.symbols, id: \.self) { symbol in
                        Button {
                            preset.symbol = symbol
                        } label: {
                            Image(systemName: symbol)
                                .frame(width: 32, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(preset.symbol == symbol ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(SessionPreset.symbolNames[symbol] ?? symbol)
                        .accessibilityAddTraits(preset.symbol == symbol ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }

            Section("Timing & repeats") {
                TimingFields(preset: $preset)
            }

            Section {
                Toggle("Long break", isOn: Binding(
                    get: { preset.hasLongBreak },
                    set: { preset.longBreakMinutes = $0 ? max(preset.breakMinutes * 2, 15) : 0 }
                ))
                if preset.hasLongBreak {
                    Stepper(value: $preset.longBreakMinutes, in: 1...120) {
                        LabeledContent("Length", value: "\(preset.longBreakMinutes) min")
                    }
                    Stepper(value: $preset.longBreakEvery, in: 1...12) {
                        LabeledContent("After every", value: "\(preset.longBreakEvery) round\(preset.longBreakEvery == 1 ? "" : "s")")
                    }
                }
            } header: {
                Text("Long break")
            } footer: {
                Text(summary)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var summary: String {
        if let total = preset.totalMinutes {
            return "One session runs \(Format.minutes(total)): \(preset.rounds) × \(preset.focusMinutes) min of focus with breaks between."
        }
        return "Cycles \(preset.focusMinutes) min focus and \(preset.breakMinutes) min break until you stop it."
    }
}
