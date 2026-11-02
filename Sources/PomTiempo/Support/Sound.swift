import AppKit

/// Plays the system's alert sounds (Glass, Hero, Purr, …) at the app's own volume.
@MainActor
enum Sound {
    static let names: [String] = {
        let dir = URL(fileURLWithPath: "/System/Library/Sounds")
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let found = files.map { $0.deletingPathExtension().lastPathComponent }.sorted()
        return found.isEmpty
            ? ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]
            : found
    }()

    /// NSSound stops when released, so the ones still ringing are held here.
    private static var playing: [NSSound] = []

    static func play(_ name: String, volume: Double, times: Int = 1) {
        guard volume > 0 else { return }
        for i in 0..<max(1, times) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.9) {
                MainActor.assumeIsolated {
                    guard let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
                    sound.volume = Float(volume)
                    playing.removeAll { !$0.isPlaying }
                    playing.append(sound)
                    sound.play()
                }
            }
        }
    }
}
