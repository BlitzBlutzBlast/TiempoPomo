import AppKit
import Combine

enum Phase: String {
    case idle, focus, shortBreak, longBreak, complete

    var isBreak: Bool { self == .shortBreak || self == .longBreak }

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long Break"
        case .complete: return "Done"
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "timer"
        case .focus: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "figure.walk"
        case .complete: return "checkmark.seal"
        }
    }
}

/// Runs a session: counts down each focus round and break, chimes and
/// notifies at each change, and keeps today's totals.
@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var round = 1
    @Published private(set) var isRunning = false
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var phaseDuration: TimeInterval = 1
    /// The session being run: a saved preset, or one changed for this run only.
    @Published private(set) var plan: SessionPreset
    @Published private(set) var isCustomized = false
    @Published private(set) var todayFocusMinutes = 0
    @Published private(set) var todayRounds = 0

    private let settings: AppSettings
    private let notifier: Notifier
    /// The countdown is measured against a deadline, not by counting ticks,
    /// so it stays right when the Mac is busy or the timer fires late.
    private var endDate: Date?
    private var ticker: Timer?
    private var activity: NSObjectProtocol?

    init(settings: AppSettings, notifier: Notifier, preset: SessionPreset) {
        self.settings = settings
        self.notifier = notifier
        self.plan = preset
        loadStats()
        resetToStart()
    }

    /// Nothing is under way, so the session can be swapped or changed.
    var isIdle: Bool { phase == .idle || phase == .complete }
    var isPaused: Bool { !isIdle && !isRunning }
    /// The phase the dial's colours follow: Ready looks like the focus it leads to.
    var displayPhase: Phase { phase == .idle ? .focus : phase }
    /// Fraction of the current phase still to go, 1 → 0.
    var fractionLeft: Double {
        if phase == .complete { return 0 }
        return phaseDuration > 0 ? min(1, max(0, remaining / phaseDuration)) : 1
    }

    var roundText: String {
        plan.repeatForever ? "Round \(round)" : "Round \(min(round, plan.rounds)) of \(plan.rounds)"
    }

    /// What comes after the current phase, for the "Up next" line.
    var upNext: String? {
        switch phase {
        case .idle, .complete:
            return nil
        case .focus:
            if !plan.repeatForever && round >= plan.rounds { return "Session complete" }
            return isLongBreakDue ? "Long break · \(plan.longBreakMinutes) min" : "Break · \(plan.breakMinutes) min"
        case .shortBreak, .longBreak:
            return "Focus · \(plan.focusMinutes) min"
        }
    }

    // MARK: Controls

    func load(_ preset: SessionPreset) {
        guard isIdle else { return }
        plan = preset
        isCustomized = false
        resetToStart()
    }

    /// Changes the timings for this run only; the saved preset is untouched.
    func customize(_ preset: SessionPreset) {
        guard isIdle else { return }
        plan = preset
        isCustomized = true
        resetToStart()
    }

    func start() {
        Sound.stopAll()
        if isIdle {
            phase = .focus
            round = 1
            setDuration()
            if settings.playStartSound { settings.chime(settings.startSound, once: true) }
        }
        resume()
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func pause() {
        Sound.stopAll()
        guard isRunning, let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        stopTicking()
        notifier.cancelPending()
    }

    func reset() {
        Sound.stopAll()
        stopTicking()
        notifier.cancelPending()
        resetToStart()
    }

    /// Ends the current phase now. Skipping is quiet and a skipped focus
    /// round doesn't count toward today's totals.
    func skip() {
        Sound.stopAll()
        guard !isIdle else { return }
        advance(natural: false)
    }

    // MARK: Running

    private func resetToStart() {
        phase = .idle
        round = 1
        phaseDuration = duration(for: .focus)
        remaining = phaseDuration
    }

    private func duration(for phase: Phase) -> TimeInterval {
        switch phase {
        case .idle, .focus: return TimeInterval(plan.focusMinutes * 60)
        case .shortBreak: return TimeInterval(plan.breakMinutes * 60)
        case .longBreak: return TimeInterval(plan.longBreakMinutes * 60)
        case .complete: return 1
        }
    }

    private func setDuration() {
        phaseDuration = max(1, duration(for: phase))
        remaining = phaseDuration
    }

    private var isLongBreakDue: Bool {
        plan.hasLongBreak && round % plan.longBreakEvery == 0
    }

    private var isLastRound: Bool {
        !plan.repeatForever && round >= plan.rounds
    }

    private func resume() {
        guard !isRunning, !isIdle else { return }
        if remaining <= 0 { remaining = phaseDuration }
        let end = Date().addingTimeInterval(remaining)
        endDate = end
        isRunning = true
        startTicking()
        scheduleNotification(at: end)
    }

    private func startTicking() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        // Keeps App Nap from slowing the timer while the window is hidden.
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "PomTiempo timer running")
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
        endDate = nil
        isRunning = false
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0 {
            remaining = 0
            advance(natural: true)
        } else {
            remaining = left
        }
    }

    /// Moves to the next phase. `natural` is a phase that ran out on its own:
    /// it chimes, counts, and its notification has already been delivered.
    private func advance(natural: Bool) {
        stopTicking()
        if !natural { notifier.cancelPending() }

        switch phase {
        case .focus:
            if natural { recordFocusRound() }
            if isLastRound {
                phase = .complete
                remaining = 0
                phaseDuration = 1
                if natural { settings.chime(settings.completeSound) }
                return
            }
            phase = isLongBreakDue ? .longBreak : .shortBreak
            setDuration()
            if natural { settings.chime(settings.focusEndSound) }
            if settings.autoStartBreaks { resume() }

        case .shortBreak, .longBreak:
            round += 1
            phase = .focus
            setDuration()
            if natural { settings.chime(settings.breakEndSound) }
            if settings.autoStartFocus { resume() }

        case .idle, .complete:
            break
        }
    }

    private func scheduleNotification(at end: Date) {
        let event: Notifier.Event
        switch phase {
        case .focus:
            event = isLastRound ? .sessionComplete : .focusEnded(longBreak: isLongBreakDue)
        case .shortBreak, .longBreak:
            event = .breakEnded
        case .idle, .complete:
            return
        }
        notifier.schedule(event, at: end, plan: plan, round: round)
    }

    // MARK: Today

    private enum StatsKey {
        static let day = "stats.day"
        static let minutes = "stats.minutes"
        static let rounds = "stats.rounds"
    }

    private static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func loadStats() {
        let d = UserDefaults.standard
        if d.string(forKey: StatsKey.day) == Self.today {
            todayFocusMinutes = d.integer(forKey: StatsKey.minutes)
            todayRounds = d.integer(forKey: StatsKey.rounds)
        } else {
            todayFocusMinutes = 0
            todayRounds = 0
        }
    }

    private func recordFocusRound() {
        loadStats()
        todayFocusMinutes += plan.focusMinutes
        todayRounds += 1
        let d = UserDefaults.standard
        d.set(Self.today, forKey: StatsKey.day)
        d.set(todayFocusMinutes, forKey: StatsKey.minutes)
        d.set(todayRounds, forKey: StatsKey.rounds)
    }

    func resetTodayStats() {
        UserDefaults.standard.removeObject(forKey: StatsKey.day)
        loadStats()
    }
}
