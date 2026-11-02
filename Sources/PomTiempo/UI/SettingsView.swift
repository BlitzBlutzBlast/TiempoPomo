import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var engine: TimerEngine
    @EnvironmentObject private var notifier: Notifier
    @Environment(\.dismiss) private var dismiss

    /// The sheet from the main window has a Done button; the ⌘, window doesn't need one.
    var showsDone = false

    @State private var tab: Tab = .sounds
    @State private var importProblems: [String] = []

    enum Tab: String, CaseIterable, Identifiable {
        case sounds = "Sounds"
        case notifications = "Notifications"
        case general = "General"
        var id: String { rawValue }
    }

    var body: some View {
        let theme = settings.theme
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 340)
            .padding(.top, 18)

            Group {
                switch tab {
                case .sounds: soundsForm
                case .notifications: notificationsForm
                case .general: generalForm
                }
            }
            .formStyle(.grouped)

            if showsDone {
                HStack {
                    Spacer()
                    Button("Done") { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding([.horizontal, .bottom], 16)
            }
        }
        .frame(width: 500, height: 500)
        .themedPane(theme)
        .task { await notifier.refreshStatus() }
    }

    // MARK: Sounds

    private var soundsForm: some View {
        Form {
            Section {
                Toggle("Play sounds", isOn: $settings.soundsEnabled)
                HStack(spacing: 10) {
                    Text("Volume")
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $settings.volume, in: 0...1) { editing in
                        if !editing {
                            Sound.stopAll()
                            Sound.play(settings.focusEndSound, volume: settings.volume)
                        }
                    }
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    Text("\(Int(settings.volume * 100))%")
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                Stepper(value: $settings.chimeRepeats, in: 1...5) {
                    HStack {
                        Text("Ring each chime")
                        Spacer()
                        Text(settings.chimeRepeats == 1 ? "once" : "\(settings.chimeRepeats) times")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Pressing Start, Pause, Skip or Reset silences a chime that's still repeating.")
                    .foregroundStyle(.secondary)
            }

            Section("Chimes") {
                soundPicker("Focus ends · break begins", selection: $settings.focusEndSound)
                soundPicker("Break ends · focus starts again", selection: $settings.breakEndSound)
                soundPicker("Whole session complete", selection: $settings.completeSound)
                Toggle("Chime when I start a session", isOn: $settings.playStartSound)
                if settings.playStartSound {
                    soundPicker("Start sound", selection: $settings.startSound)
                }
            }
            .disabled(!settings.soundsEnabled)

            Section {
                if settings.customSounds.isEmpty {
                    Text("Add short audio files (MP3, M4A, WAV, AIFF, CAF; up to 30 seconds) to use them as chimes.")
                        .foregroundStyle(.secondary)
                }
                ForEach(settings.customSounds, id: \.self) { key in
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundStyle(.secondary)
                        Text(Sound.displayName(key))
                        Spacer()
                        Button {
                            Sound.stopAll()
                            Sound.play(key, volume: settings.volume)
                        } label: { Image(systemName: "play.circle") }
                            .buttonStyle(.borderless)
                            .help("Preview")
                        Button(role: .destructive) {
                            settings.deleteCustomSound(key)
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("Remove")
                    }
                }
                Button("Add Sound…") { addSounds() }
            } header: {
                Text("Your sounds")
            } footer: {
                Text("PomTiempo keeps its own copy of each file and can only open the files you choose here.")
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Some sounds weren't added", isPresented: Binding(
            get: { !importProblems.isEmpty },
            set: { if !$0 { importProblems = [] } }
        )) {
            Button("OK") { importProblems = [] }
        } message: {
            Text(importProblems.joined(separator: "\n"))
        }
    }

    private func addSounds() {
        let panel = NSOpenPanel()
        panel.title = "Add Sounds"
        panel.prompt = "Add"
        panel.allowedContentTypes = Sound.importTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        importProblems = settings.importSounds(from: panel.urls)
    }

    private func soundPicker(_ title: String, selection: Binding<String>) -> some View {
        HStack {
            Picker(title, selection: selection) {
                Section("PomTiempo") {
                    ForEach(Sound.appKeys, id: \.self) { Text(Sound.displayName($0)).tag($0) }
                }
                if !settings.customSounds.isEmpty {
                    Section("Your sounds") {
                        ForEach(settings.customSounds, id: \.self) { Text(Sound.displayName($0)).tag($0) }
                    }
                }
                Section("macOS") {
                    ForEach(Sound.systemKeys, id: \.self) { Text(Sound.displayName($0)).tag($0) }
                }
            }
            .onChange(of: selection.wrappedValue) { _, key in
                Sound.stopAll()
                Sound.play(key, volume: settings.volume)
            }
            Button {
                Sound.stopAll()
                Sound.play(selection.wrappedValue, volume: settings.volume, times: settings.chimeRepeats)
            } label: {
                Image(systemName: "play.circle")
            }
            .buttonStyle(.borderless)
            .help("Preview, with repeats")
        }
    }

    // MARK: Notifications

    private var notificationsForm: some View {
        Form {
            Section {
                LabeledContent("Permission") {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(notifier.isAllowed ? Color.green : (notifier.status == .denied ? .red : .orange))
                            .frame(width: 8, height: 8)
                        Text(notifier.isAvailable ? notifier.statusText : "Unavailable outside the app bundle")
                    }
                }
                if notifier.status == .notDetermined {
                    Button("Allow Notifications…") {
                        Task { await notifier.requestAuthorization() }
                    }
                } else if notifier.status == .denied {
                    HStack {
                        Button("Open System Settings…") { notifier.openSystemSettings() }
                        Button("Ask Again") { Task { await notifier.requestAuthorization() } }
                    }
                }
            } footer: {
                if let error = notifier.lastError {
                    Text("macOS couldn't turn on notifications: \(error)")
                        .foregroundStyle(.secondary)
                } else if notifier.status == .denied {
                    Text("macOS is blocking PomTiempo's notifications. Turn them on under Notifications → PomTiempo, then come back.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Show notifications", isOn: $settings.notificationsEnabled)
                    .onChange(of: settings.notificationsEnabled) { _, on in
                        if on { Task { await notifier.requestIfNeeded() } } else { notifier.cancelPending() }
                    }
            }

            Section("Notify me when") {
                Toggle("A focus round ends and a break begins", isOn: $settings.notifyFocusEnd)
                Toggle("A break ends and focus starts again", isOn: $settings.notifyBreakEnd)
                Toggle("The whole session is complete", isOn: $settings.notifyComplete)
            }
            .disabled(!settings.notificationsEnabled)

            Section {
                Toggle("Only when PomTiempo is in the background", isOn: $settings.notifyOnlyInBackground)
                Toggle("Play the system notification sound too", isOn: $settings.notificationSound)
            } header: {
                Text("Style")
            } footer: {
                Text("When auto-start is off, notifications get a Start button so you can begin the next round right from the banner. Banner style (temporary or persistent) is set in System Settings → Notifications.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!settings.notificationsEnabled)

            Section {
                HStack {
                    Button("Send Test Notification") { notifier.sendTest() }
                        .disabled(!notifier.isAllowed)
                    Spacer()
                    Button("Notification Settings…") { notifier.openSystemSettings() }
                        .buttonStyle(.link)
                }
            }
        }
    }

    // MARK: General

    private var generalForm: some View {
        Form {
            Section("Timer") {
                Toggle("Start breaks automatically", isOn: $settings.autoStartBreaks)
                Toggle("Start the next focus round automatically", isOn: $settings.autoStartFocus)
            }
            Section("Window") {
                Toggle("Show countdown in the menu bar", isOn: $settings.showMenuBarTimer)
                Toggle("Keep window on top of other apps", isOn: $settings.floatOnTop)
            }
            Section {
                LabeledContent("Today", value: "\(Format.minutes(engine.todayFocusMinutes)) · \(engine.todayRounds) rounds")
                Button("Reset Today's Totals") { engine.resetTodayStats() }
            } header: {
                Text("Stats")
            } footer: {
                Text("Space starts and pauses the timer. ⌘R resets, ⌘→ skips.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
