import Foundation
import SwiftUI

/// The saved sessions, and which one the main window is set to.
@MainActor
final class PresetStore: ObservableObject {
    private static let presetsKey = "presets.v1"
    private static let selectedKey = "presets.selected"

    @Published var presets: [SessionPreset] {
        didSet { save() }
    }

    @Published var selectedID: UUID {
        didSet { UserDefaults.standard.set(selectedID.uuidString, forKey: Self.selectedKey) }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.presetsKey),
           let decoded = try? JSONDecoder().decode(LenientList<SessionPreset>.self, from: data).elements,
           !decoded.isEmpty {
            presets = decoded
        } else {
            presets = SessionPreset.builtIns
        }
        let saved = UserDefaults.standard.string(forKey: Self.selectedKey).flatMap(UUID.init(uuidString:))
        selectedID = saved ?? SessionPreset.defaultSession.id
        if !presets.contains(where: { $0.id == selectedID }) { selectedID = presets[0].id }
    }

    var selected: SessionPreset {
        presets.first { $0.id == selectedID } ?? presets[0]
    }

    func binding(for id: UUID) -> Binding<SessionPreset>? {
        guard presets.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in self?.presets.first { $0.id == id } ?? .defaultSession },
            set: { [weak self] new in
                guard let self, let i = self.presets.firstIndex(where: { $0.id == id }) else { return }
                self.presets[i] = new
            }
        )
    }

    @discardableResult
    func add() -> SessionPreset {
        let preset = SessionPreset(name: uniqueName("New Session"), symbol: "timer",
                                   focusMinutes: 25, breakMinutes: 5, rounds: 4)
        presets.append(preset)
        return preset
    }

    @discardableResult
    func duplicate(_ id: UUID) -> SessionPreset? {
        guard let i = presets.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = presets[i]
        copy.id = UUID()
        copy.name = uniqueName(copy.name + " Copy")
        presets.insert(copy, at: i + 1)
        return copy
    }

    func delete(_ id: UUID) {
        guard presets.count > 1 else { return }
        presets.removeAll { $0.id == id }
        if selectedID == id { selectedID = presets[0].id }
    }

    func update(_ preset: SessionPreset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[i] = preset
    }

    /// Puts back any of the four starting sessions that were deleted, and
    /// resets the ones still here to their original timings.
    func restoreBuiltIns() {
        for builtIn in SessionPreset.builtIns {
            if let i = presets.firstIndex(where: { $0.id == builtIn.id }) {
                presets[i] = builtIn
            } else {
                presets.append(builtIn)
            }
        }
    }

    private func uniqueName(_ base: String) -> String {
        var name = base
        var n = 2
        while presets.contains(where: { $0.name == name }) {
            name = "\(base) \(n)"
            n += 1
        }
        return name
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: Self.presetsKey)
        }
    }
}
