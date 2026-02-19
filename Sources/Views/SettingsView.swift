import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("focusDuration") private var focusDuration = 25
    @AppStorage("shortBreakDuration") private var shortBreakDuration = 5
    @AppStorage("longBreakDuration") private var longBreakDuration = 15
    @AppStorage("longBreakInterval") private var longBreakInterval = 4
    @AppStorage("autoStartFocus") private var autoStartFocus = false
    @AppStorage("alertSound") private var alertSound = "Glass"
    @AppStorage("showTimerInMenuBar") private var showTimerInMenuBar = true

    @State private var launchAtLogin = false

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    var body: some View {
        Form {
            Section("Timer Durations") {
                Stepper("Focus: \(focusDuration) min", value: $focusDuration, in: 1...120)
                Stepper("Short break: \(shortBreakDuration) min", value: $shortBreakDuration, in: 1...60)
                Stepper("Long break: \(longBreakDuration) min", value: $longBreakDuration, in: 1...60)
                Stepper("Long break every \(longBreakInterval) pomos", value: $longBreakInterval, in: 2...10)
            }

            Section("Behavior") {
                Toggle("Auto-start focus after break", isOn: $autoStartFocus)
                Toggle("Show timer in menu bar", isOn: $showTimerInMenuBar)
            }

            Section("Sound") {
                Picker("Alert sound", selection: $alertSound) {
                    ForEach(SoundManager.availableSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }
                .onChange(of: alertSound) { newValue in
                    SoundManager().playPreview(soundName: newValue)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        updateLaunchAtLogin(enabled: newValue)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
            // Revert toggle if failed
            launchAtLogin = !enabled
        }
    }
}
