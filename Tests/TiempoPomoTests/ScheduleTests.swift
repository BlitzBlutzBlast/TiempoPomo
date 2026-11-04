import Foundation
import Testing
@testable import TiempoPomo

private func preset(focus: Int = 25, rest: Int = 5, rounds: Int = 4, forever: Bool = false,
                    long: Int = 0, every: Int = 4) -> SessionPreset {
    SessionPreset(name: "Test", symbol: "timer", focusMinutes: focus, breakMinutes: rest, rounds: rounds,
                  repeatForever: forever, longBreakMinutes: long, longBreakEvery: every)
}

/// Every phase from Start to the end, as the timer would walk it.
private func walk(_ plan: SessionPreset, limit: Int = 50) -> [Phase] {
    var phase = Phase.idle, round = 0, seen: [Phase] = []
    while seen.count < limit {
        (phase, round) = plan.step(from: phase, round: round)
        seen.append(phase)
        if phase == .complete { break }
    }
    return seen
}

@Suite struct ScheduleTests {
    @Test func fourRoundsHaveThreeBreaks() {
        #expect(walk(preset()) == [.focus, .shortBreak, .focus, .shortBreak, .focus, .shortBreak, .focus, .complete])
    }

    @Test func oneRoundEndsAfterFocus() {
        #expect(walk(preset(rounds: 1)) == [.focus, .complete])
    }

    @Test func longBreakReplacesEveryNthShortBreak() {
        let phases = walk(preset(rounds: 6, long: 15, every: 2))
        #expect(phases == [.focus, .shortBreak, .focus, .longBreak, .focus, .shortBreak,
                           .focus, .longBreak, .focus, .shortBreak, .focus, .complete])
    }

    @Test func noLongBreakAfterTheLastRound() {
        // Round 4 is the last, so the long break due after it never comes.
        #expect(!walk(preset(rounds: 4, long: 15, every: 4)).contains(.longBreak))
    }

    @Test func repeatForeverNeverCompletes() {
        let phases = walk(preset(rounds: 2, forever: true), limit: 40)
        #expect(phases.count == 40)
        #expect(!phases.contains(.complete))
    }

    @Test func roundsCountUpAcrossBreaks() {
        let plan = preset()
        #expect(plan.step(from: .idle, round: 0).round == 1)
        #expect(plan.step(from: .focus, round: 1).round == 1)
        #expect(plan.step(from: .shortBreak, round: 1).round == 2)
        #expect(plan.step(from: .complete, round: 4) == (.complete, 4))
    }

    @Test func durations() {
        let plan = preset(focus: 50, rest: 10, long: 20)
        #expect(plan.duration(of: .focus) == 3000)
        #expect(plan.duration(of: .idle) == 3000)
        #expect(plan.duration(of: .shortBreak) == 600)
        #expect(plan.duration(of: .longBreak) == 1200)
        #expect(plan.duration(of: .complete) == 0)
    }

    @Test func upNext() {
        let plan = preset(rounds: 2, long: 15, every: 1)
        #expect(plan.upNext(from: .idle, round: 0) == nil)
        #expect(plan.upNext(from: .focus, round: 1) == "Long break · 15 min")
        #expect(plan.upNext(from: .longBreak, round: 1) == "Focus · 25 min")
        #expect(plan.upNext(from: .focus, round: 2) == "Session complete")
        #expect(plan.upNext(from: .complete, round: 2) == nil)
    }

    @Test func roundText() {
        #expect(preset().roundText(2) == "Round 2 of 4")
        #expect(preset().roundText(9) == "Round 4 of 4")
        #expect(preset(forever: true).roundText(9) == "Round 9")
    }

    @Test func totalMinutes() {
        #expect(preset().totalMinutes == 4 * 25 + 3 * 5)
        #expect(preset(rounds: 4, long: 15, every: 2).totalMinutes == 4 * 25 + 5 + 15 + 5)
        #expect(preset(rounds: 1).totalMinutes == 25)
        #expect(preset(forever: true).totalMinutes == nil)
    }
}

@Suite struct PresetDecodingTests {
    private func decode(_ json: String) throws -> [SessionPreset] {
        try JSONDecoder().decode(LenientList<SessionPreset>.self, from: Data(json.utf8)).elements
    }

    @Test func missingFieldsTakeDefaults() throws {
        let presets = try decode(#"[{"name": "Old", "focusMinutes": 40}]"#)
        #expect(presets.count == 1)
        #expect(presets[0].name == "Old")
        #expect(presets[0].focusMinutes == 40)
        #expect(presets[0].breakMinutes == 5)
        #expect(presets[0].rounds == 4)
        #expect(presets[0].repeatForever == false)
        #expect(presets[0].longBreakMinutes == 0)
    }

    @Test func badEntriesAreSkippedNotFatal() throws {
        let presets = try decode(#"[{"name": "A"}, 42, "nope", {"name": 7}, null, {"name": "B"}]"#)
        #expect(presets.map(\.name) == ["A", "B"])
    }

    @Test func outOfRangeValuesAreClamped() throws {
        let p = try decode(#"[{"focusMinutes": 0, "breakMinutes": -3, "rounds": 0, "longBreakMinutes": -1, "longBreakEvery": 0}]"#)[0]
        #expect(p.focusMinutes == 1 && p.breakMinutes == 1 && p.rounds == 1)
        #expect(p.longBreakMinutes == 0 && p.longBreakEvery == 1)
    }

    @Test func roundTrips() throws {
        let original = preset(focus: 30, rest: 7, rounds: 3, forever: true, long: 12, every: 2)
        let data = try JSONEncoder().encode([original])
        #expect(try JSONDecoder().decode(LenientList<SessionPreset>.self, from: data).elements == [original])
    }
}

@Suite struct FormatTests {
    @Test func clock() {
        #expect(Format.clock(0) == "00:00")
        #expect(Format.clock(59.2) == "01:00")
        #expect(Format.clock(25 * 60) == "25:00")
        #expect(Format.clock(3899) == "1:04:59")
        #expect(Format.clock(-5) == "00:00")
    }

    @Test func minutes() {
        #expect(Format.minutes(0) == "0 min")
        #expect(Format.minutes(45) == "45 min")
        #expect(Format.minutes(60) == "1h")
        #expect(Format.minutes(95) == "1h 35m")
    }
}

/// Every palette must be readable on its own glass: WCAG AA, 4.5:1 for text
/// and 3:1 for shapes, in every mood.
@Suite struct ContrastTests {
    @Test(arguments: Palette.all)
    func paletteMeetsAA(_ palette: Palette) {
        for check in palette.contrastChecks {
            #expect(check.ratio >= check.minimum,
                    "\(palette.name) \(check.what): \(String(format: "%.2f", check.ratio)) < \(check.minimum)")
        }
    }

    @Test func idsAreUniqueAndUnknownFallsBack() {
        #expect(Set(Palette.all.map(\.id)).count == Palette.all.count)
        #expect(Palette.named("no-such-palette").id == Palette.dusk.id)
    }
}

extension Palette: CustomTestStringConvertible {
    public var testDescription: String { name }
}
