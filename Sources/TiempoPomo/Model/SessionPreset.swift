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

}

/// Sessions saved by an older or newer version load even when fields are
/// missing: anything absent takes its default, so adding a field to a session
/// never wipes the ones already saved.
extension SessionPreset {
    enum CodingKeys: String, CodingKey {
        case id, name, symbol, focusMinutes, breakMinutes, rounds, repeatForever, longBreakMinutes, longBreakEvery
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try c.decodeIfPresent(String.self, forKey: .name) ?? "Session",
            symbol: try c.decodeIfPresent(String.self, forKey: .symbol) ?? "timer",
            focusMinutes: max(1, try c.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25),
            breakMinutes: max(1, try c.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5),
            rounds: max(1, try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 4),
            repeatForever: try c.decodeIfPresent(Bool.self, forKey: .repeatForever) ?? false,
            longBreakMinutes: max(0, try c.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 0),
            longBreakEvery: max(1, try c.decodeIfPresent(Int.self, forKey: .longBreakEvery) ?? 4)
        )
    }
}

/// Decodes a list where one unreadable entry is skipped instead of failing
/// the whole list.
struct LenientList<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? container.decode(Skip.self)
            }
        }
        self.elements = elements
    }

    /// Accepts any value, so the list moves past an entry it can't read.
    private struct Skip: Decodable {
        init(from decoder: Decoder) {}
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

    /// Spoken names for the icons, for VoiceOver.
    static let symbolNames: [String: String] = [
        "timer": "Timer", "graduationcap": "Graduation cap", "book": "Book", "leaf": "Leaf",
        "brain.head.profile": "Brain", "pencil": "Pencil", "laptopcomputer": "Laptop",
        "music.note": "Music", "dumbbell": "Dumbbell", "paintbrush": "Paintbrush",
        "flame": "Flame", "moon.stars": "Moon and stars",
    ]

    static let symbols: [String] = [
        "timer", "graduationcap", "book", "leaf", "brain.head.profile", "pencil",
        "laptopcomputer", "music.note", "dumbbell", "paintbrush", "flame", "moon.stars",
    ]
}
