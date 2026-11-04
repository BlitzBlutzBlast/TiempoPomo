import AppKit
import UserNotifications

/// Posts the banners at each change of phase. Each one is scheduled for the
/// moment the phase will end, so it arrives on time even if the app is busy
/// or hidden, and is withdrawn if the timer is paused, skipped or reset.
@MainActor
final class Notifier: NSObject, ObservableObject {
    enum Event {
        case focusEnded(longBreak: Bool)
        case breakEnded
        case sessionComplete
    }

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined
    /// What macOS said if asking for permission failed.
    @Published private(set) var lastError: String?

    /// Called when the "Start" button on a banner is clicked.
    var onStartNext: (() -> Void)?

    private let settings: AppSettings
    private let pendingID = "tiempopomo.phase-end"
    nonisolated private static let startAction = "start-next"
    private static let waitingCategory = "waiting"
    nonisolated static let testKey = "test"

    /// Notification Center needs a real app bundle; `swift run` has none.
    private let center: UNUserNotificationCenter?

    init(settings: AppSettings) {
        self.settings = settings
        center = Bundle.main.bundleIdentifier != nil ? UNUserNotificationCenter.current() : nil
        super.init()
        guard let center else { return }
        center.delegate = self
        // Coming back from System Settings → Notifications should show the new state.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refreshStatus() }
        }
        let start = UNNotificationAction(identifier: Self.startAction, title: "Start", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.waitingCategory, actions: [start], intentIdentifiers: [], options: [])
        ])
        Task { await refreshStatus() }
    }

    var isAvailable: Bool { center != nil }

    var statusText: String {
        switch status {
        case .authorized, .provisional: return "Allowed"
        case .denied: return "Turned off in System Settings"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    var isAllowed: Bool {
        [.authorized, .provisional].contains(status)
    }

    func refreshStatus() async {
        guard let center else { return }
        status = await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async {
        guard let center else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            NSLog("Tiempo Pomo notification authorization failed: %@", String(describing: error))
        }
        await refreshStatus()
    }

    /// Asks once, the first time it matters.
    func requestIfNeeded() async {
        await refreshStatus()
        if settings.notificationsEnabled && status == .notDetermined {
            await requestAuthorization()
        }
    }

    func schedule(_ event: Event, at date: Date, plan: SessionPreset, round: Int) {
        cancelPending()
        guard let center, settings.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        let waits: Bool
        switch event {
        case .focusEnded(let longBreak):
            guard settings.notifyFocusEnd else { return }
            let minutes = longBreak ? plan.longBreakMinutes : plan.breakMinutes
            content.title = "Focus round \(round) done"
            content.body = "Time for a \(minutes)-minute \(longBreak ? "long break" : "break")."
            waits = !settings.autoStartBreaks
        case .breakEnded:
            guard settings.notifyBreakEnd else { return }
            content.title = "Break's over"
            let of = plan.repeatForever ? "" : " of \(plan.rounds)"
            content.body = "Round \(round + 1)\(of): \(plan.focusMinutes) minutes of focus."
            waits = !settings.autoStartFocus
        case .sessionComplete:
            guard settings.notifyComplete else { return }
            content.title = "Session complete"
            content.body = "You finished \(plan.name): \(plan.rounds) round\(plan.rounds == 1 ? "" : "s") of focus."
            waits = false
        }
        if waits {
            content.body += " Press Start when you're ready."
            content.categoryIdentifier = Self.waitingCategory
        }
        content.subtitle = plan.name
        content.sound = settings.notificationSound ? .default : nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: pendingID, content: content, trigger: trigger))
    }

    func cancelPending() {
        center?.removePendingNotificationRequests(withIdentifiers: [pendingID])
    }

    func sendTest() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Tiempo Pomo"
        content.body = "Notifications are working. You'll see one like this when a round or break ends."
        content.sound = settings.notificationSound ? .default : nil
        content.userInfo = [Self.testKey: true]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        center.add(UNNotificationRequest(identifier: "tiempopomo.test", content: content, trigger: trigger))
    }

    func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let isTest = notification.request.content.userInfo[Self.testKey] as? Bool ?? false
        let onlyInBackground = AppSettings.saved(AppSettings.Key.notifyOnlyInBackground, false)
        let active = await MainActor.run { NSApp.isActive }
        if onlyInBackground && active && !isTest { return [] }
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        await MainActor.run {
            if action == Self.startAction {
                self.onStartNext?()
            } else if action == UNNotificationDefaultActionIdentifier {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
