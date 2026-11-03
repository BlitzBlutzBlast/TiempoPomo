<p align="center">
  <img src="Resources/AppIcon-1024.png" width="160" alt="PomTiempo icon: a glowing countdown ring on violet glass with a little tomato stem on top">
</p>

<h1 align="center">PomTiempo</h1>

A calm, glassy Pomodoro timer for macOS. One centred dial, your own session presets, chimes and notifications at every change, and a countdown in the menu bar. Colours are borrowed from [Glassine](https://github.com/BlitzBlutzBlast/glassine).

## Download

From [Releases](../../releases/latest), pick one:

- **PomTiempo-x.y.z.pkg**: double-click and it installs into Applications. The first time, approve it in System Settings → Privacy & Security → *Open Anyway*.
- **PomTiempo-x.y.z.dmg**: drag the app to Applications, then **right-click → Open** the first time.

The app is ad-hoc signed, not notarized, so macOS asks once.

## Privacy: no internet, enforced

PomTiempo never goes online. That's enforced, not just promised:

- It runs in the **App Sandbox with no network entitlement** ([`Resources/PomTiempo.entitlements`](Resources/PomTiempo.entitlements)), so macOS refuses any connection it tries to make. Its only other permission is read-only access to an audio file you pick in *Add Sound…*.
- [`scripts/check_no_network.sh`](scripts/check_no_network.sh) runs on every build. It fails the build if the source uses a networking API, if the binary imports networking symbols or frameworks, or if the signed app isn't sandboxed or holds a network entitlement.
- No dependencies, no updater, no analytics, no account. Presets and settings live in the app's sandbox container on your Mac.

## What's in it

- **Main timer**: a ring that drains clockwise as the round runs. While the timer runs, it ripples into a wave that flows around it (drawn with Core Animation, about 4% CPU, and nothing at all when stopped). Start / Pause, Skip and Reset sit underneath. **Change session time** tweaks the next run without touching the saved session. The window is a fixed size, laid out on one grid.
- **Sessions** (*Update Defaults*): add, name, duplicate and delete sessions. Each one has focus and break length, number of rounds or *repeat until stopped*, and an optional long break every N rounds. It starts with:

  | Session | Focus | Break | Rounds |
  |---|---|---|---|
  | Default Session | 40 min | 15 min | 4 |
  | School Study | 50 min | 10 min | 4 |
  | Reading Session | 30 min | 5 min | 3 |
  | Mindfulness Session | 10 min | 3 min | 2 |

- **App Colors**: eleven palettes. Nine glass palettes come from Glassine (Dusk, Ocean, Lavender, Graphite, Sepia Night, Midnight, Moss, Frost, Paper). **Vivid** uses Apple's dark-mode system colours as multi-colour gradients over glass lit from behind. **Claude** uses Anthropic's brand palette: ink on warm paper, orange for focus, blue for breaks, green when done, in a serif face.
- **Settings**
  - *Sounds*: master volume, and a separate chime for "focus ends → break", "break ends → focus", "session complete" and "session start". Chimes ring 3 times by default (1–5), and Start, Pause, Skip or Reset silences them. Pick from PomTiempo's own pack of 10 (Singing Bowl, Soft Bell, Bright Ding, Rising Chimes, Gentle Gong, Marimba Up/Down, Kalimba, Wood Blocks, Triple Beep), the macOS alert sounds, or **your own audio files** (*Add Sound…*: MP3/M4A/WAV/AIFF/CAF, up to 30 s).
  - *Notifications*: permission status, on/off for each of the three events, "only when in the background", the system banner sound, and a test button. When auto-start is off, banners get a **Start** button.
  - *General*: auto-start breaks and focus rounds, menu bar countdown, keep the window on top, and today's totals.
- **Shortcuts**: Space starts or pauses, ⌘↩ starts or pauses from anywhere in the app, ⌘→ skips, ⌘R resets.

## Build it yourself

```bash
./build.sh 0.1.0          # → dist/PomTiempo.app, PomTiempo-0.1.0.dmg and PomTiempo-0.1.0.pkg
```

Swift package, no Xcode project and no dependencies. Needs macOS 14+ and the Swift toolchain (Xcode or the Command Line Tools). Pushing a `v*` tag makes GitHub Actions build a universal DMG and attach it to a release.

`scripts/make_icon.swift` redraws the icon; regenerate `Resources/AppIcon.icns` from it with `sips` + `iconutil`. `scripts/make_sounds.swift Resources/Sounds` re-synthesises the built-in sound pack. Every sound is generated from sine partials, so it's all original.
