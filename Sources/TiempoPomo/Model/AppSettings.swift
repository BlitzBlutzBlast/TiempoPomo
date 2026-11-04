import Foundation
import SwiftUI

/// Everything in Settings and App Colors, saved to UserDefaults as it changes.
@MainActor
final class AppSettings: ObservableObject {
    enum Key {
        static let soundsEnabled = "soundsEnabled"
        static let volume = "volume"
        static let chimeRepeats = "chimeRepeats"
        static let focusEndSound = "focusEndSound"
        static let breakEndSound = "breakEndSound"
        static let completeSound = "completeSound"
        static let playStartSound = "playStartSound"
        static let startSound = "startSound"

        static let notificationsEnabled = "notificationsEnabled"
        static let notifyFocusEnd = "notifyFocusEnd"
        static let notifyBreakEnd = "notifyBreakEnd"
        static let notifyComplete = "notifyComplete"
        static let notifyOnlyInBackground = "notifyOnlyInBackground"
        static let notificationSound = "notificationSound"

        static let autoStartBreaks = "autoStartBreaks"
        static let autoStartFocus = "autoStartFocus"
        static let showMenuBarTimer = "showMenuBarTimer"
        static let floatOnTop = "floatOnTop"
        static let hideDockIconWhenClosed = "hideDockIconWhenClosed"
        static let menuBarStyle = "menuBarStyle"
        static let themeID = "themeID"
    }

    nonisolated private static func load<T>(_ key: String, _ fallback: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? fallback
    }

    /// Earlier versions saved macOS sounds by bare name ("Glass").
    nonisolated private static func soundKey(_ raw: String) -> String {
        raw.contains(":") ? raw : "system:" + raw
    }

    private func store(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: Sounds

    @Published var soundsEnabled: Bool = load(Key.soundsEnabled, true) { didSet { store(soundsEnabled, Key.soundsEnabled) } }
    @Published var volume: Double = load(Key.volume, 0.7) { didSet { store(volume, Key.volume) } }
    /// How many times a chime rings, for when once is easy to miss.
    @Published var chimeRepeats: Int = load(Key.chimeRepeats, 3) { didSet { store(chimeRepeats, Key.chimeRepeats) } }
    /// Focus round ends, break begins.
    @Published var focusEndSound: String = soundKey(load(Key.focusEndSound, "app:Singing Bowl")) { didSet { store(focusEndSound, Key.focusEndSound) } }
    /// Break ends, the next focus round begins.
    @Published var breakEndSound: String = soundKey(load(Key.breakEndSound, "app:Marimba Up")) { didSet { store(breakEndSound, Key.breakEndSound) } }
    /// The last round of the session is done.
    @Published var completeSound: String = soundKey(load(Key.completeSound, "app:Rising Chimes")) { didSet { store(completeSound, Key.completeSound) } }
    @Published var playStartSound: Bool = load(Key.playStartSound, true) { didSet { store(playStartSound, Key.playStartSound) } }
    @Published var startSound: String = soundKey(load(Key.startSound, "app:Soft Bell")) { didSet { store(startSound, Key.startSound) } }
    /// Sound files the user added, as "custom:" keys.
    @Published private(set) var customSounds: [String] = Sound.customKeys()

    /// Adds sound files picked in the Open panel; returns messages for any that were refused.
    func importSounds(from urls: [URL]) -> [String] {
        var problems: [String] = []
        for url in urls {
            do { _ = try Sound.importSound(from: url) } catch { problems.append(error.localizedDescription) }
        }
        customSounds = Sound.customKeys()
        return problems
    }

    /// Removes an added sound; any chime that used it goes back to the default.
    func deleteCustomSound(_ key: String) {
        Sound.deleteCustom(key)
        customSounds = Sound.customKeys()
        if focusEndSound == key { focusEndSound = "app:Singing Bowl" }
        if breakEndSound == key { breakEndSound = "app:Marimba Up" }
        if completeSound == key { completeSound = "app:Rising Chimes" }
        if startSound == key { startSound = "app:Soft Bell" }
    }

    // MARK: Notifications

    @Published var notificationsEnabled: Bool = load(Key.notificationsEnabled, true) { didSet { store(notificationsEnabled, Key.notificationsEnabled) } }
    @Published var notifyFocusEnd: Bool = load(Key.notifyFocusEnd, true) { didSet { store(notifyFocusEnd, Key.notifyFocusEnd) } }
    @Published var notifyBreakEnd: Bool = load(Key.notifyBreakEnd, true) { didSet { store(notifyBreakEnd, Key.notifyBreakEnd) } }
    @Published var notifyComplete: Bool = load(Key.notifyComplete, true) { didSet { store(notifyComplete, Key.notifyComplete) } }
    @Published var notifyOnlyInBackground: Bool = load(Key.notifyOnlyInBackground, false) { didSet { store(notifyOnlyInBackground, Key.notifyOnlyInBackground) } }
    /// The banner's own system sound, on top of Tiempo Pomo's chime.
    @Published var notificationSound: Bool = load(Key.notificationSound, false) { didSet { store(notificationSound, Key.notificationSound) } }

    // MARK: General

    @Published var autoStartBreaks: Bool = load(Key.autoStartBreaks, true) { didSet { store(autoStartBreaks, Key.autoStartBreaks) } }
    @Published var autoStartFocus: Bool = load(Key.autoStartFocus, true) { didSet { store(autoStartFocus, Key.autoStartFocus) } }
    @Published var showMenuBarTimer: Bool = load(Key.showMenuBarTimer, true) {
        didSet { store(showMenuBarTimer, Key.showMenuBarTimer); AppDelegate.updateDockIcon() }
    }
    /// With the window closed, leave the Dock and live in the menu bar only.
    /// Needs the menu bar timer, or there'd be no way back to the app.
    @Published var hideDockIconWhenClosed: Bool = load(Key.hideDockIconWhenClosed, true) {
        didSet { store(hideDockIconWhenClosed, Key.hideDockIconWhenClosed); AppDelegate.updateDockIcon() }
    }
    @Published var floatOnTop: Bool = load(Key.floatOnTop, false) { didSet { store(floatOnTop, Key.floatOnTop) } }
    /// Minutes by default: the menu bar item then redraws once a minute, not every second.
    @Published var menuBarStyle: MenuBarStyle = MenuBarStyle(rawValue: load(Key.menuBarStyle, MenuBarStyle.minutes.rawValue)) ?? .minutes {
        didSet { store(menuBarStyle.rawValue, Key.menuBarStyle) }
    }

    enum MenuBarStyle: String, CaseIterable, Identifiable {
        case minutes, seconds, icon
        var id: String { rawValue }
        var label: String {
            switch self {
            case .minutes: return "Minutes left (25m)"
            case .seconds: return "Minutes and seconds (24:59)"
            case .icon: return "Icon only"
            }
        }
    }

    /// Whether the mini timer window is open. It follows the window itself,
    /// so the Settings switch, the menu bar item and the pill's ✕ agree.
    @Published var showMiniTimer = false

    /// Which Settings tab to show; set just before opening the window.
    @Published var settingsTab: SettingsTab = .sessions

    enum SettingsTab: String, Hashable {
        case sessions, appearance, sounds, notifications, general
    }

    // MARK: Colors

    @Published var themeID: String = load(Key.themeID, AppTheme.dusk.id) { didSet { store(themeID, Key.themeID) } }

    var theme: AppTheme { AppTheme.all.first { $0.id == themeID } ?? .dusk }

    /// Rings a chime the set number of times; `once` for the start sound.
    func chime(_ key: String, once: Bool = false) {
        guard soundsEnabled else { return }
        Sound.play(key, volume: volume, times: once ? 1 : chimeRepeats)
    }
}
