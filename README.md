<p align="center">
  <img src="Resources/AppIcon-1024.png" width="160" alt="PomTiempo icon: a glowing countdown ring on violet glass with a little tomato stem on top">
</p>

<h1 align="center">PomTiempo</h1>

A calm, glassy Pomodoro timer for macOS. One centred dial, your own session presets, chimes and notifications at every change, and a countdown in the menu bar. Colours are borrowed from [Glassine](https://github.com/BlitzBlutzBlast/glassine).

## Download

Grab the latest **PomTiempo-x.y.z.dmg** from [Releases](../../releases/latest), drag the app to Applications, then **right-click → Open** the first time (it's ad-hoc signed, not notarized).

## What's in it

- **Main timer**: a big ring that drains as the round runs, with Start / Pause, Skip and Reset. **Change session time** tweaks the next run without touching the saved session.
- **Sessions** (*Update Defaults*): add, name, duplicate and delete sessions. Each one has focus and break length, number of rounds or *repeat until stopped*, and an optional long break every N rounds. It starts with:

  | Session | Focus | Break | Rounds |
  |---|---|---|---|
  | Default Session | 40 min | 15 min | 4 |
  | School Study | 50 min | 10 min | 4 |
  | Reading Session | 30 min | 5 min | 3 |
  | Mindfulness Session | 10 min | 3 min | 2 |

- **App Colors**: nine glass palettes from Glassine (Dusk, Ocean, Lavender, Graphite, Sepia Night, Midnight, Moss, Frost, Paper). Each has one colour for focus and one for breaks.
- **Settings**
  - *Sounds*: master volume, a separate chime for "focus ends → break", "break ends → focus", "session complete" and "session start", and how many times each chime rings.
  - *Notifications*: permission status, on/off for each of the three events, "only when in the background", the system banner sound, and a test button. When auto-start is off, banners get a **Start** button.
  - *General*: auto-start breaks and focus rounds, menu bar countdown, keep the window on top, and today's totals.
- **Shortcuts**: Space starts or pauses, ⌘↩ starts or pauses from anywhere in the app, ⌘→ skips, ⌘R resets.

## Build it yourself

```bash
./build.sh 0.1.0          # → dist/PomTiempo.app and dist/PomTiempo-0.1.0.dmg
```

Swift package, no Xcode project and no dependencies. Needs macOS 14+ and the Swift toolchain (Xcode or the Command Line Tools). Pushing a `v*` tag makes GitHub Actions build a universal DMG and attach it to a release.

`scripts/make_icon.swift` redraws the icon; regenerate `Resources/AppIcon.icns` from it with `sips` + `iconutil`.
