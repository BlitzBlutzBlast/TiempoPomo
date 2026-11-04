import Foundation

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

/// How a session runs, as plain rules with no clocks or side effects: what
/// comes after each phase, how long it lasts, and what to call it. The timer
/// follows these; the tests check them.
extension SessionPreset {
    func duration(of phase: Phase) -> TimeInterval {
        switch phase {
        case .idle, .focus: return TimeInterval(focusMinutes * 60)
        case .shortBreak: return TimeInterval(breakMinutes * 60)
        case .longBreak: return TimeInterval(longBreakMinutes * 60)
        case .complete: return 0
        }
    }

    func isLastRound(_ round: Int) -> Bool {
        !repeatForever && round >= rounds
    }

    /// A long break replaces the short one after every `longBreakEvery` rounds.
    func isLongBreakDue(afterRound round: Int) -> Bool {
        hasLongBreak && round % longBreakEvery == 0
    }

    /// The phase after `phase` in `round`, and the round it falls in.
    func step(from phase: Phase, round: Int) -> (phase: Phase, round: Int) {
        switch phase {
        case .idle:
            return (.focus, 1)
        case .focus:
            if isLastRound(round) { return (.complete, round) }
            return (isLongBreakDue(afterRound: round) ? .longBreak : .shortBreak, round)
        case .shortBreak, .longBreak:
            return (.focus, round + 1)
        case .complete:
            return (.complete, round)
        }
    }

    /// "Break · 10 min", for the line under the time.
    func upNext(from phase: Phase, round: Int) -> String? {
        guard phase != .idle, phase != .complete else { return nil }
        let next = step(from: phase, round: round).phase
        switch next {
        case .complete: return "Session complete"
        case .shortBreak: return "Break · \(breakMinutes) min"
        case .longBreak: return "Long break · \(longBreakMinutes) min"
        case .focus: return "Focus · \(focusMinutes) min"
        case .idle: return nil
        }
    }

    func roundText(_ round: Int) -> String {
        repeatForever ? "Round \(round)" : "Round \(min(round, rounds)) of \(rounds)"
    }
}
