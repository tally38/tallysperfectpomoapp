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
    @AppStorage("blockingOverlay") private var blockingOverlay = false

    @State private var launchAtLogin = false
    @State private var customTypes: [String] = []
    @State private var newTypeName: String = ""

    @State private var focusText = ""
    @State private var shortBreakText = ""
    @State private var longBreakText = ""
    @State private var longBreakIntervalText = ""

    private let accentColor = Color(red: 232/255, green: 93/255, blue: 74/255)

    var body: some View {
        Form {
            Section("Timer Durations") {
                durationField("Focus", text: $focusText, suffix: "min", range: 1...120) {
                    focusDuration = $0
                }
                durationField("Short break", text: $shortBreakText, suffix: "min", range: 1...60) {
                    shortBreakDuration = $0
                }
                durationField("Long break", text: $longBreakText, suffix: "min", range: 1...60) {
                    longBreakDuration = $0
                }
                durationField("Long break every", text: $longBreakIntervalText, suffix: "pomos", range: 2...10) {
                    longBreakInterval = $0
                }
            }

            Section("Behavior") {
                Toggle("Auto-start focus after break", isOn: $autoStartFocus)
                Toggle("Show timer in menu bar", isOn: $showTimerInMenuBar)
                Toggle("Block background until entry is submitted", isOn: $blockingOverlay)
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

            Section("Pomo Types") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Built-in: focus, meeting")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(customTypes, id: \.self) { typeName in
                    HStack {
                        Text(typeName)
                        Spacer()
                        Button(role: .destructive) {
                            removeCustomType(typeName)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    TextField("New type name", text: $newTypeName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        addCustomType()
                    }
                    .disabled(newTypeName.trimmingCharacters(in: .whitespaces).isEmpty)
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
            customTypes = UserDefaults.standard.stringArray(forKey: "customPomoTypes") ?? []
            focusText = "\(focusDuration)"
            shortBreakText = "\(shortBreakDuration)"
            longBreakText = "\(longBreakDuration)"
            longBreakIntervalText = "\(longBreakInterval)"
        }
    }

    @ViewBuilder
    private func durationField(
        _ label: String,
        text: Binding<String>,
        suffix: String,
        range: ClosedRange<Int>,
        onCommit: @escaping (Int) -> Void
    ) -> some View {
        let isInvalid = !text.wrappedValue.isEmpty && Int(text.wrappedValue) == nil
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                Spacer()
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)
                    .multilineTextAlignment(.trailing)
                    .border(isInvalid ? Color.red : Color.clear, width: 1)
                    .onSubmit {
                        commitDuration(text: text, range: range, onCommit: onCommit)
                    }
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
            if isInvalid {
                Text("Enter a whole number (\(range.lowerBound)–\(range.upperBound))")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func commitDuration(
        text: Binding<String>,
        range: ClosedRange<Int>,
        onCommit: @escaping (Int) -> Void
    ) {
        if let value = Int(text.wrappedValue) {
            let clamped = min(max(value, range.lowerBound), range.upperBound)
            onCommit(clamped)
            text.wrappedValue = "\(clamped)"
        } else {
            // Reset to lower bound if input is not a valid number
            onCommit(range.lowerBound)
            text.wrappedValue = "\(range.lowerBound)"
        }
    }

    private static let builtInTypes = ["focus", "meeting"]

    private func addCustomType() {
        let name = newTypeName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty,
              !Self.builtInTypes.contains(name),
              !customTypes.contains(name) else { return }
        customTypes.append(name)
        UserDefaults.standard.set(customTypes, forKey: "customPomoTypes")
        newTypeName = ""
    }

    private func removeCustomType(_ name: String) {
        customTypes.removeAll { $0 == name }
        UserDefaults.standard.set(customTypes, forKey: "customPomoTypes")
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
