import AppKit
import Combine

/// One second of the countdown, as shown.
struct Tick: Equatable {
    /// Whole seconds left.
    var seconds = 0
    /// Fraction of the phase still to go, 1 → 0.
    var fraction: Double = 1
}

/// The part of the timer that changes every second, kept apart from
/// `TimerEngine` so a tick redraws only the views that show the time, not the
/// whole window, the menus and the controls. It publishes once per tick.
@MainActor
final class Countdown: ObservableObject {
    @Published fileprivate(set) var tick = Tick()

    var seconds: Int { tick.seconds }
    var fraction: Double { tick.fraction }

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
/// notifies at each change, and keeps today's totals. What follows what is
/// decided by the session's rules (see Schedule.swift); this only keeps time.
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
    private var settingsWatch: AnyCancellable?
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
        // The menu bar's display style is a setting; refresh after any change.
        settingsWatch = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.publishTime() }
        }
    }

    // MARK: State, as the views show it

    /// Nothing is under way, so the session can be swapped or changed.
    var isIdle: Bool { phase == .idle || phase == .complete }
    /// The phase the colours follow: Ready looks like the focus it leads to.
    var displayPhase: Phase { phase == .idle ? .focus : phase }
    /// Fraction of the current phase still to go, 1 → 0.
    var fractionLeft: Double {
        if phase == .complete { return 0 }
        return phaseDuration > 0 ? min(1, max(0, remaining / phaseDuration)) : 1
    }

    var roundText: String { plan.roundText(round) }
    var upNext: String? { plan.upNext(from: phase, round: round) }
    var showsRounds: Bool { plan.repeatForever || plan.rounds > 1 }

    /// The main button's title, the same everywhere it appears.
    var primaryActionTitle: String {
        switch phase {
        case .idle: return "Start"
        case .complete: return "Start Again"
        default:
            if isRunning { return "Pause" }
            // Paused by hand, or waiting because auto-start is off.
            return phaseStarted ? "Resume" : "Start \(phase.label)"
        }
    }

    var skipTitle: String { phase.isBreak ? "Skip break" : "Skip to break" }

    /// "4 rounds · 2h 40m focused", for the end of a session.
    var sessionSummary: String {
        guard sessionRounds > 0 else { return "Rounds were skipped" }
        let r = "\(sessionRounds) round\(sessionRounds == 1 ? "" : "s")"
        return sessionFocusMinutes > 0 ? "\(r) · \(Format.minutes(sessionFocusMinutes)) focused" : r
    }

    private func publishTime() {
        if countdown.isWatched {
            let tick = Tick(seconds: max(0, Int(remaining.rounded(.up))), fraction: fractionLeft)
            if countdown.tick != tick { countdown.tick = tick }
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
            (phase, round) = plan.step(from: .idle, round: 0)
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
        phaseDuration = plan.duration(of: .focus)
        remaining = phaseDuration
    }

    private func setDuration() {
        phaseStarted = false
        phaseDuration = max(1, plan.duration(of: phase))
        remaining = phaseDuration
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
        let finished = phase
        if finished == .focus && natural { recordFocusRound() }

        let (next, nextRound) = plan.step(from: finished, round: round)
        phase = next
        round = nextRound

        if next == .complete {
            remaining = 0
            phaseDuration = 1
            if natural { settings.chime(settings.completeSound) }
            return
        }
        setDuration()
        if natural { settings.chime(next == .focus ? settings.breakEndSound : settings.focusEndSound) }
        if next == .focus ? settings.autoStartFocus : settings.autoStartBreaks { resume() }
    }

    private func scheduleNotification(at end: Date) {
        let event: Notifier.Event
        switch phase {
        case .focus:
            event = plan.isLastRound(round) ? .sessionComplete : .focusEnded(longBreak: plan.isLongBreakDue(afterRound: round))
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

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static var today: String { dayFormatter.string(from: Date()) }

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
