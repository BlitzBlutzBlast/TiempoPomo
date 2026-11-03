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

/// The part of the timer that changes every second, kept apart from
/// `TimerEngine` so a tick redraws only the views that show the time (the
/// digits and the ring), not the whole window, the menus and the cards.
@MainActor
final class Countdown: ObservableObject {
    /// Whole seconds left, as shown.
    @Published fileprivate(set) var seconds = 0
    /// Fraction of the phase still to go, 1 → 0.
    @Published fileprivate(set) var fraction: Double = 1

    /// Windows currently on screen that show the countdown. With none, the
    /// timer keeps counting but stops redrawing anything.
    private var watchers = Set<ObjectIdentifier>()
    fileprivate var refresh: (() -> Void)?

    var isWatched: Bool { !watchers.isEmpty }

    func setVisible(_ visible: Bool, for viewer: ObjectIdentifier) {
        let was = isWatched
        if visible { watchers.insert(viewer) } else { watchers.remove(viewer) }
        if !was && isWatched { refresh?() }
    }
}

/// What the menu bar item shows. It only publishes when its text actually
/// changes, which with the default minutes display is once a minute: the
/// menu bar item is one of the costliest things the app redraws.
@MainActor
final class MenuBarClock: ObservableObject {
    /// nil shows the icon alone.
    @Published fileprivate(set) var text: String?
    @Published fileprivate(set) var symbol = "timer"
}

/// Runs a session: counts down each focus round and break, chimes and
/// notifies at each change, and keeps today's totals.
@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var round = 1
    @Published private(set) var isRunning = false
    /// The current phase has been started, so the main button says Resume.
    @Published private(set) var phaseStarted = false
    @Published private(set) var phaseDuration: TimeInterval = 1
    /// The session being run: a saved preset, or one changed for this run only.
    @Published private(set) var plan: SessionPreset
    @Published private(set) var isCustomized = false
    @Published private(set) var todayFocusMinutes = 0
    @Published private(set) var todayRounds = 0
    /// Focus rounds finished (not skipped) in the current session, for the summary.
    @Published private(set) var sessionRounds = 0
    @Published private(set) var sessionFocusMinutes = 0

    let countdown = Countdown()
    let menuClock = MenuBarClock()

    /// Time left in the phase. Not published: it feeds `countdown` and
    /// `menuClock`, which publish only when what they show changes.
    private var remaining: TimeInterval = 0 {
        didSet { publishTime() }
    }

    private let settings: AppSettings
    private let notifier: Notifier
    private var styleWatch: AnyCancellable?
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
        countdown.refresh = { [weak self] in self?.publishTime() }
        styleWatch = settings.$menuBarStyle.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.publishTime() }
        }
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

    private func publishTime() {
        if countdown.isWatched {
            let seconds = max(0, Int(remaining.rounded(.up)))
            if countdown.seconds != seconds { countdown.seconds = seconds }
            let fraction = fractionLeft
            if countdown.fraction != fraction { countdown.fraction = fraction }
        }

        let text: String?
        if isIdle {
            text = nil
        } else {
            switch settings.menuBarStyle {
            case .seconds: text = Format.clock(remaining)
            case .minutes: text = "\(max(1, Int((remaining / 60).rounded(.up))))m"
            case .icon: text = nil
            }
        }
        if menuClock.text != text { menuClock.text = text }
        let symbol = isIdle ? "timer" : (isRunning ? phase.symbol : "pause.circle")
        if menuClock.symbol != symbol { menuClock.symbol = symbol }
    }

    /// "4 rounds · 2h 40m focused", for the end of a session.
    var sessionSummary: String {
        guard sessionRounds > 0 else { return "Rounds were skipped" }
        let r = "\(sessionRounds) round\(sessionRounds == 1 ? "" : "s")"
        return sessionFocusMinutes > 0 ? "\(r) · \(Format.minutes(sessionFocusMinutes)) focused" : r
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
            sessionRounds = 0
            sessionFocusMinutes = 0
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
        phaseStarted = false
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
        phaseStarted = false
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
        phaseStarted = true
        publishTime()
        startTicking()
        scheduleNotification(at: end)
    }

    private func startTicking() {
        scheduleTick()
        // Keeps App Nap from delaying the chime while the window is hidden.
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "Tiempo Pomo timer running")
        }
    }

    /// Wakes once, exactly when the displayed second next changes (or when
    /// the phase ends), instead of polling: one wake-up a second, with a
    /// little tolerance so macOS can line it up with other work.
    private func scheduleTick() {
        ticker?.invalidate()
        guard let endDate else { return }
        let shown = endDate.timeIntervalSinceNow.rounded(.up)
        let next = shown > 1 ? endDate.addingTimeInterval(-(shown - 1)) : endDate
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.03
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
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
        publishTime()
    }

    private func tick() {
        guard let endDate else { return }
        let left = endDate.timeIntervalSinceNow
        if left <= 0.001 {
            remaining = 0
            advance(natural: true)
        } else {
            remaining = left
            scheduleTick()
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
        sessionRounds += 1
        sessionFocusMinutes += plan.focusMinutes
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
