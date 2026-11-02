import Foundation

/// A named recipe for a session: how long to focus, how long to rest, and how
/// many times to go around.
struct SessionPreset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var symbol: String
    var focusMinutes: Int
    var breakMinutes: Int
    /// Focus rounds in one session. Breaks sit between rounds, so a session of
    /// four rounds has three breaks and ends when the fourth round does.
    var rounds: Int
    /// Keep cycling focus and break until stopped; `rounds` is then ignored.
    var repeatForever: Bool = false
    /// 0 turns the long break off.
    var longBreakMinutes: Int = 0
    /// A long break replaces the short one after every this-many rounds.
    var longBreakEvery: Int = 4

    var hasLongBreak: Bool { longBreakMinutes > 0 && longBreakEvery > 0 }

    /// Total length of one pass through the session, in minutes.
    var totalMinutes: Int? {
        guard !repeatForever else { return nil }
        var total = focusMinutes * rounds
        for round in 1..<max(rounds, 1) {
            total += (hasLongBreak && round % longBreakEvery == 0) ? longBreakMinutes : breakMinutes
        }
        return total
    }

    var roundsText: String {
        repeatForever ? "repeats until stopped" : "× \(rounds) round\(rounds == 1 ? "" : "s")"
    }
}

extension SessionPreset {
    static let defaultSession = SessionPreset(
        id: UUID(uuidString: "6B1D2F0A-0000-4000-8000-000000000001")!,
        name: "Default Session", symbol: "timer",
        focusMinutes: 40, breakMinutes: 15, rounds: 4
    )
    static let schoolStudy = SessionPreset(
        id: UUID(uuidString: "6B1D2F0A-0000-4000-8000-000000000002")!,
        name: "School Study", symbol: "graduationcap",
        focusMinutes: 50, breakMinutes: 10, rounds: 4
    )
    static let reading = SessionPreset(
        id: UUID(uuidString: "6B1D2F0A-0000-4000-8000-000000000003")!,
        name: "Reading Session", symbol: "book",
        focusMinutes: 30, breakMinutes: 5, rounds: 3
    )
    static let mindfulness = SessionPreset(
        id: UUID(uuidString: "6B1D2F0A-0000-4000-8000-000000000004")!,
        name: "Mindfulness Session", symbol: "leaf",
        focusMinutes: 10, breakMinutes: 3, rounds: 2
    )

    static let builtIns: [SessionPreset] = [defaultSession, schoolStudy, reading, mindfulness]

    static let symbols: [String] = [
        "timer", "graduationcap", "book", "leaf", "brain.head.profile", "pencil",
        "laptopcomputer", "music.note", "dumbbell", "paintbrush", "flame", "moon.stars",
    ]
}
