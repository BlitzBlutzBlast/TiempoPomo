import SwiftUI

@main
struct TiempoPomoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings: AppSettings
    @StateObject private var store: PresetStore
    @StateObject private var notifier: Notifier
    @StateObject private var engine: TimerEngine

    init() {
        let settings = AppSettings()
        let store = PresetStore()
        let notifier = Notifier(settings: settings)
        let engine = TimerEngine(settings: settings, notifier: notifier, preset: store.selected)
        notifier.onStartNext = { [weak engine] in engine?.start() }
        AppDelegate.engine = engine
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
        _notifier = StateObject(wrappedValue: notifier)
        _engine = StateObject(wrappedValue: engine)
    }

    var body: some Scene {
        Window("Tiempo Pomo", id: "main") {
            MainView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(notifier)
                .environmentObject(engine)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Timer") {
                // The shortcuts (⌘↩, ⌘→, ⌘R) are handled by AppDelegate's key monitor.
                Button(engine.isRunning ? "Pause  ⌘↩" : "Start  ⌘↩") { engine.toggle() }
                Button("Skip  ⌘→") { engine.skip() }
                    .disabled(engine.isIdle)
                Button("Reset  ⌘R") { engine.reset() }
                    .disabled(engine.isIdle)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(store)
                .environmentObject(notifier)
                .environmentObject(engine)
        }

        Window("Mini Timer", id: "mini") {
            MiniTimerView()
                .environmentObject(settings)
                .environmentObject(engine)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)

        // MenuBarExtra writes this binding back on every update; writing the
        // same value would republish settings and redraw forever.
        MenuBarExtra(isInserted: Binding(
            get: { settings.showMenuBarTimer },
            set: { if settings.showMenuBarTimer != $0 { settings.showMenuBarTimer = $0 } }
        )) {
            MenuBarPanel()
                .environmentObject(settings)
                .environmentObject(engine)
                .environmentObject(store)
        } label: {
            MenuBarLabel(clock: engine.menuClock)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static weak var engine: TimerEngine?
    private var keyMonitor: Any?

    /// ⌘↩ start/pause, ⌘→ skip, ⌘R reset. Done with a key monitor rather
    /// than `.keyboardShortcut` on the Timer menu's buttons, which crashes
    /// some toolchain/OS pairings inside Commands.
    func applicationDidFinishLaunching(_ notification: Notification) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard mods == .command || mods == [.command, .numericPad, .function],
                  let engine = MainActor.assumeIsolated({ AppDelegate.engine }) else { return event }
            switch event.keyCode {
            case 36, 76: // return, enter
                MainActor.assumeIsolated { engine.toggle() }
                return nil
            case 124: // right arrow
                MainActor.assumeIsolated { engine.skip() }
                return nil
            case 15: // R
                MainActor.assumeIsolated { engine.reset() }
                return nil
            default:
                return event
            }
        }
    }

    /// With the menu bar timer on, closing the window keeps the timer running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(UserDefaults.standard.object(forKey: AppSettings.Key.showMenuBarTimer) as? Bool ?? true)
    }
}
