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
        static let themeID = "themeID"
    }

    nonisolated private static func load<T>(_ key: String, _ fallback: T) -> T {
        UserDefaults.standard.object(forKey: key) as? T ?? fallback
    }

    private func store(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: Sounds

    @Published var soundsEnabled: Bool = load(Key.soundsEnabled, true) { didSet { store(soundsEnabled, Key.soundsEnabled) } }
    @Published var volume: Double = load(Key.volume, 0.7) { didSet { store(volume, Key.volume) } }
    /// How many times a chime rings, for when once is easy to miss.
    @Published var chimeRepeats: Int = load(Key.chimeRepeats, 1) { didSet { store(chimeRepeats, Key.chimeRepeats) } }
    /// Focus round ends, break begins.
    @Published var focusEndSound: String = load(Key.focusEndSound, "Glass") { didSet { store(focusEndSound, Key.focusEndSound) } }
    /// Break ends, the next focus round begins.
    @Published var breakEndSound: String = load(Key.breakEndSound, "Hero") { didSet { store(breakEndSound, Key.breakEndSound) } }
    /// The last round of the session is done.
    @Published var completeSound: String = load(Key.completeSound, "Purr") { didSet { store(completeSound, Key.completeSound) } }
    @Published var playStartSound: Bool = load(Key.playStartSound, true) { didSet { store(playStartSound, Key.playStartSound) } }
    @Published var startSound: String = load(Key.startSound, "Tink") { didSet { store(startSound, Key.startSound) } }

    // MARK: Notifications

    @Published var notificationsEnabled: Bool = load(Key.notificationsEnabled, true) { didSet { store(notificationsEnabled, Key.notificationsEnabled) } }
    @Published var notifyFocusEnd: Bool = load(Key.notifyFocusEnd, true) { didSet { store(notifyFocusEnd, Key.notifyFocusEnd) } }
    @Published var notifyBreakEnd: Bool = load(Key.notifyBreakEnd, true) { didSet { store(notifyBreakEnd, Key.notifyBreakEnd) } }
    @Published var notifyComplete: Bool = load(Key.notifyComplete, true) { didSet { store(notifyComplete, Key.notifyComplete) } }
    @Published var notifyOnlyInBackground: Bool = load(Key.notifyOnlyInBackground, false) { didSet { store(notifyOnlyInBackground, Key.notifyOnlyInBackground) } }
    /// The banner's own system sound, on top of PomTiempo's chime.
    @Published var notificationSound: Bool = load(Key.notificationSound, false) { didSet { store(notificationSound, Key.notificationSound) } }

    // MARK: General

    @Published var autoStartBreaks: Bool = load(Key.autoStartBreaks, true) { didSet { store(autoStartBreaks, Key.autoStartBreaks) } }
    @Published var autoStartFocus: Bool = load(Key.autoStartFocus, true) { didSet { store(autoStartFocus, Key.autoStartFocus) } }
    @Published var showMenuBarTimer: Bool = load(Key.showMenuBarTimer, true) { didSet { store(showMenuBarTimer, Key.showMenuBarTimer) } }
    @Published var floatOnTop: Bool = load(Key.floatOnTop, false) { didSet { store(floatOnTop, Key.floatOnTop) } }

    // MARK: Colors

    @Published var themeID: String = load(Key.themeID, AppTheme.dusk.id) { didSet { store(themeID, Key.themeID) } }

    var theme: AppTheme { AppTheme.all.first { $0.id == themeID } ?? .dusk }

    func chime(_ name: String) {
        guard soundsEnabled else { return }
        Sound.play(name, volume: volume, times: chimeRepeats)
    }
}
