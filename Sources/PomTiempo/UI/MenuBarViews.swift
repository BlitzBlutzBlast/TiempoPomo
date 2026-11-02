import SwiftUI

/// The countdown shown in the menu bar.
struct MenuBarLabel: View {
    @EnvironmentObject private var engine: TimerEngine

    var body: some View {
        if engine.isIdle {
            Image(systemName: "timer")
        } else {
            HStack(spacing: 4) {
                Image(systemName: engine.isRunning ? engine.phase.symbol : "pause.circle")
                Text(Format.clock(engine.remaining))
                    .monospacedDigit()
            }
        }
    }
}

struct MenuBarMenu: View {
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var store: PresetStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(status)

        Button(engine.isRunning ? "Pause" : (engine.isIdle ? "Start Timer" : "Resume")) { engine.toggle() }
        if !engine.isIdle {
            Button(engine.phase.isBreak ? "Skip Break" : "Skip to Break") { engine.skip() }
            Button("Reset") { engine.reset() }
        }

        Divider()

        Menu("Session") {
            ForEach(store.presets) { preset in
                Button {
                    store.selectedID = preset.id
                    engine.load(preset)
                } label: {
                    if preset.id == store.selectedID {
                        Label(preset.name, systemImage: "checkmark")
                    } else {
                        Text(preset.name)
                    }
                }
            }
        }
        .disabled(!engine.isIdle)

        Divider()

        Button("Open PomTiempo") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit PomTiempo") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var status: String {
        switch engine.phase {
        case .idle: return "\(engine.plan.name) · ready"
        case .complete: return "\(engine.plan.name) · complete"
        default:
            let state = engine.isRunning ? "" : " (paused)"
            return "\(engine.phase.label) · \(engine.roundText)\(state)"
        }
    }
}
