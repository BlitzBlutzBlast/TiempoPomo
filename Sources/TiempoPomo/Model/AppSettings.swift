import Combine
import Foundation
import SwiftUI

/// A value that can be saved in UserDefaults as-is.
protocol DefaultsValue {
    init?(defaultsObject: Any)
    var defaultsObject: Any { get }
}

extension Bool: DefaultsValue {
    init?(defaultsObject: Any) { guard let v = defaultsObject as? Bool else { return nil }; self = v }
    var defaultsObject: Any { self }
}
extension Int: DefaultsValue {
    init?(defaultsObject: Any) { guard let v = defaultsObject as? Int else { return nil }; self = v }
    var defaultsObject: Any { self }
}
extension Double: DefaultsValue {
    init?(defaultsObject: Any) { guard let v = defaultsObject as? Double else { return nil }; self = v }
    var defaultsObject: Any { self }
}
extension String: DefaultsValue {
    init?(defaultsObject: Any) { guard let v = defaultsObject as? String else { return nil }; self = v }
    var defaultsObject: Any { self }
}
extension DefaultsValue where Self: RawRepresentable, RawValue: DefaultsValue {
    init?(defaultsObject: Any) {
        guard let raw = RawValue(defaultsObject: defaultsObject) else { return nil }
        self.init(rawValue: raw)
    }
    var defaultsObject: Any { rawValue.defaultsObject }
}

/// A setting saved to UserDefaults the moment it changes, that also tells
/// SwiftUI to redraw. One line per setting instead of three.
@propertyWrapper
struct Stored<Value: DefaultsValue> {
    let key: String
    private var value: Value
    private let onChange: (@MainActor () -> Void)?

    /// `normalize` cleans up values saved by older versions as they load.
    init(wrappedValue fallback: Value, _ key: String,
         normalize: (Value) -> Value = { $0 }, onChange: (@MainActor () -> Void)? = nil) {
        self.key = key
        self.onChange = onChange
        let saved = UserDefaults.standard.object(forKey: key).flatMap(Value.init(defaultsObject:))
        value = normalize(saved ?? fallback)
    }

    @available(*, unavailable, message: "Stored is only for properties of AppSettings")
    var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    @MainActor
    static subscript(
        _enclosingInstance settings: AppSettings,
        wrapped _: ReferenceWritableKeyPath<AppSettings, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<AppSettings, Stored>
    ) -> Value {
        get { settings[keyPath: storageKeyPath].value }
        set {
            settings.objectWillChange.send()
            settings[keyPath: storageKeyPath].value = newValue
            let stored = settings[keyPath: storageKeyPath]
            UserDefaults.standard.set(newValue.defaultsObject, forKey: stored.key)
            stored.onChange?()
        }
    }
}

/// Everything in Settings, saved to UserDefaults as it changes.
@MainActor
final class AppSettings: ObservableObject {
    /// Every saved setting's key, in one place. Code that reads settings
    /// outside this class (the app delegate, the notification delegate) uses
    /// these through `AppSettings.saved`.
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

    /// Reads a saved setting from outside the main actor or before this class
    /// exists, with the same default the property uses.
    nonisolated static func saved<Value: DefaultsValue>(_ key: String, _ fallback: Value) -> Value {
        UserDefaults.standard.object(forKey: key).flatMap(Value.init(defaultsObject:)) ?? fallback
    }

    /// Earlier versions saved macOS sounds by bare name ("Glass").
    nonisolated static func soundKey(_ raw: String) -> String {
        raw.contains(":") ? raw : "system:" + raw
    }

    // MARK: Sounds

    static let defaultSounds = (focusEnd: "app:Singing Bowl", breakEnd: "app:Marimba Up",
                                complete: "app:Rising Chimes", start: "app:Soft Bell")

    @Stored(Key.soundsEnabled) var soundsEnabled = true
    @Stored(Key.volume) var volume = 0.7
    /// How many times a chime rings, for when once is easy to miss.
    @Stored(Key.chimeRepeats) var chimeRepeats = 3
    /// Focus round ends, break begins.
    @Stored(Key.focusEndSound, normalize: AppSettings.soundKey) var focusEndSound = AppSettings.defaultSounds.focusEnd
    /// Break ends, the next focus round begins.
    @Stored(Key.breakEndSound, normalize: AppSettings.soundKey) var breakEndSound = AppSettings.defaultSounds.breakEnd
    /// The last round of the session is done.
    @Stored(Key.completeSound, normalize: AppSettings.soundKey) var completeSound = AppSettings.defaultSounds.complete
    @Stored(Key.playStartSound) var playStartSound = true
    @Stored(Key.startSound, normalize: AppSettings.soundKey) var startSound = AppSettings.defaultSounds.start
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

    /// Removes an added sound; any chime that used it goes back to its default.
    func deleteCustomSound(_ key: String) {
        Sound.deleteCustom(key)
        customSounds = Sound.customKeys()
        if focusEndSound == key { focusEndSound = Self.defaultSounds.focusEnd }
        if breakEndSound == key { breakEndSound = Self.defaultSounds.breakEnd }
        if completeSound == key { completeSound = Self.defaultSounds.complete }
        if startSound == key { startSound = Self.defaultSounds.start }
    }

    /// Rings a chime the set number of times; `once` for the start sound.
    func chime(_ key: String, once: Bool = false) {
        guard soundsEnabled else { return }
        Sound.play(key, volume: volume, times: once ? 1 : chimeRepeats)
    }

    // MARK: Notifications

    @Stored(Key.notificationsEnabled) var notificationsEnabled = true
    @Stored(Key.notifyFocusEnd) var notifyFocusEnd = true
    @Stored(Key.notifyBreakEnd) var notifyBreakEnd = true
    @Stored(Key.notifyComplete) var notifyComplete = true
    @Stored(Key.notifyOnlyInBackground) var notifyOnlyInBackground = false
    /// The banner's own system sound, on top of Tiempo Pomo's chime.
    @Stored(Key.notificationSound) var notificationSound = false

    // MARK: General

    @Stored(Key.autoStartBreaks) var autoStartBreaks = true
    @Stored(Key.autoStartFocus) var autoStartFocus = true
    @Stored(Key.showMenuBarTimer, onChange: { AppDelegate.updateDockIcon() }) var showMenuBarTimer = true
    /// With the window closed, leave the Dock and live in the menu bar only.
    /// Needs the menu bar timer, or there'd be no way back to the app.
    @Stored(Key.hideDockIconWhenClosed, onChange: { AppDelegate.updateDockIcon() }) var hideDockIconWhenClosed = true
    @Stored(Key.floatOnTop) var floatOnTop = false
    /// Minutes by default: the menu bar item then redraws once a minute, not every second.
    @Stored(Key.menuBarStyle) var menuBarStyle = MenuBarStyle.minutes

    enum MenuBarStyle: String, CaseIterable, Identifiable, DefaultsValue {
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

    // MARK: Palette

    @Stored(Key.themeID) var themeID = Palette.dusk.id

    var palette: Palette { Palette.named(themeID) }
    /// The palette resolved without the Mac's accessibility adjustments, for
    /// places that only need its accent (Settings' controls).
    var theme: AppTheme { AppTheme.resolve(palette) }
}
