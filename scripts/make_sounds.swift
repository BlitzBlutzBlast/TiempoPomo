// Synthesises PomTiempo's own chimes into Resources/Sounds/*.wav: bells,
// bowls and marimba notes built from sine partials with exponential decay,
// so the sounds are original and need no licence.
// Usage: swift scripts/make_sounds.swift Resources/Sounds
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/Sounds")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let rate = 44_100.0

/// One sine component: frequency as a multiple of the note, loudness, and
/// how long it takes to fade to about a third (seconds).
typealias Partial = (ratio: Double, amp: Double, decay: Double)

struct Track {
    var samples: [Double]

    init(seconds: Double) { samples = Array(repeating: 0, count: Int(seconds * rate)) }

    mutating func note(_ freq: Double, at start: Double, partials: [Partial],
                       attack: Double = 0.004, gain: Double = 1) {
        let first = Int(start * rate)
        for i in first..<samples.count {
            let t = Double(i - first) / rate
            let env = min(1, t / attack)
            var v = 0.0
            for p in partials {
                v += p.amp * exp(-t / p.decay) * sin(2 * .pi * freq * p.ratio * t)
            }
            samples[i] += v * env * gain
        }
    }

    /// A held tone with a soft start and end, for beeps.
    mutating func tone(_ freq: Double, at start: Double, length: Double, gain: Double = 1) {
        let first = Int(start * rate), count = Int(length * rate)
        for j in 0..<count where first + j < samples.count {
            let t = Double(j) / rate
            let env = min(1, t / 0.006) * min(1, (length - t) / 0.025)
            let v = sin(2 * .pi * freq * t) + 0.12 * sin(2 * .pi * freq * 3 * t)
            samples[first + j] += v * env * gain
        }
    }

    /// A short burst of decaying noise: the "knock" in a wood block.
    mutating func knock(at start: Double, decay: Double, gain: Double) {
        var seed: UInt32 = 12345
        let first = Int(start * rate)
        for i in first..<min(samples.count, first + Int(decay * 8 * rate)) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = Double(seed >> 8) / Double(1 << 24) * 2 - 1
            samples[i] += noise * exp(-Double(i - first) / rate / decay) * gain
        }
    }

    func write(_ name: String) throws {
        let peak = samples.map(abs).max() ?? 1
        let fade = Int(0.03 * rate)
        var pcm = Data()
        for (i, s) in samples.enumerated() {
            var v = s / peak * 0.85
            let left = samples.count - i
            if left < fade { v *= Double(left) / Double(fade) }
            var int = Int16(max(-1, min(1, v)) * Double(Int16.max)).littleEndian
            pcm.append(Data(bytes: &int, count: 2))
        }
        var header = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; header.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; header.append(Data(bytes: &x, count: 2)) }
        header.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + pcm.count))
        header.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        header.append("data".data(using: .ascii)!); u32(UInt32(pcm.count))
        try (header + pcm).write(to: outDir.appendingPathComponent("\(name).wav"))
        print("wrote \(name).wav")
    }
}

func hz(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }

let bell: [Partial] = [(1, 1, 1.2), (2.76, 0.25, 0.5), (5.4, 0.08, 0.25)]
let marimba: [Partial] = [(1, 1, 0.45), (4, 0.25, 0.12), (10, 0.05, 0.03)]

var t = Track(seconds: 4.5)
t.note(196, at: 0, partials: [(1, 1, 3.5), (1.008, 0.6, 3.5), (2.76, 0.35, 2.2), (5.4, 0.15, 1.2), (8.9, 0.05, 0.6)], attack: 0.01)
try t.write("Singing Bowl")

t = Track(seconds: 2.4)
t.note(hz(76), at: 0, partials: [(1, 1, 1.6), (2.0, 0.35, 0.9), (3.0, 0.18, 0.6), (4.2, 0.12, 0.4)])
try t.write("Soft Bell")

t = Track(seconds: 1.6)
t.note(hz(88), at: 0, partials: [(1, 1, 1.0), (2.76, 0.3, 0.4), (5.4, 0.1, 0.2)])
try t.write("Bright Ding")

t = Track(seconds: 1.4)
for (i, m) in [72.0, 76, 79, 84].enumerated() { t.note(hz(m), at: Double(i) * 0.14, partials: marimba) }
try t.write("Marimba Up")

t = Track(seconds: 1.4)
for (i, m) in [84.0, 79, 76, 72].enumerated() { t.note(hz(m), at: Double(i) * 0.14, partials: marimba) }
try t.write("Marimba Down")

t = Track(seconds: 2.6)
for (i, m) in [84.0, 86, 88, 91, 93].enumerated() { t.note(hz(m), at: Double(i) * 0.18, partials: bell, gain: 0.8) }
try t.write("Rising Chimes")

t = Track(seconds: 5)
t.note(98, at: 0, partials: [(1, 1, 4.0), (1.47, 0.5, 3.0), (2.09, 0.4, 2.5), (2.56, 0.3, 2.0), (3.43, 0.15, 1.2)], attack: 0.06)
try t.write("Gentle Gong")

t = Track(seconds: 1.6)
t.note(hz(79), at: 0, partials: [(1, 1, 0.9), (5.4, 0.2, 0.08), (2, 0.1, 0.3)], attack: 0.002)
t.note(hz(86), at: 0.22, partials: [(1, 1, 0.9), (5.4, 0.2, 0.08), (2, 0.1, 0.3)], attack: 0.002)
try t.write("Kalimba")

t = Track(seconds: 0.8)
for i in 0..<3 {
    let s = Double(i) * 0.18
    t.note(900, at: s, partials: [(1, 1, 0.04), (2.4, 0.5, 0.02)], attack: 0.001)
    t.knock(at: s, decay: 0.004, gain: 0.4)
}
try t.write("Wood Blocks")

t = Track(seconds: 0.8)
for i in 0..<3 { t.tone(hz(84), at: Double(i) * 0.2, length: 0.12, gain: 0.7) }
try t.write("Triple Beep")
