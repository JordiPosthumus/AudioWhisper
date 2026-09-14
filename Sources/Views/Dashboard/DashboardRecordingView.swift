import SwiftUI
import AVFoundation
import HotKey
import AppKit

internal struct DashboardRecordingView: View {
    @AppStorage("globalHotkey") private var globalHotkey = AppDefaults.defaultGlobalHotkey
    @AppStorage("pressAndHoldEnabled") private var pressAndHoldEnabled = PressAndHoldConfiguration.defaults.enabled
    @AppStorage("pressAndHoldKeyIdentifier") private var pressAndHoldKeyIdentifier = PressAndHoldConfiguration.defaults.key.rawValue
    @AppStorage("pressAndHoldMode") private var pressAndHoldModeRaw = PressAndHoldConfiguration.defaults.mode.rawValue

    @State private var isRecordingHotkey = false
    @State private var recordedModifiers: NSEvent.ModifierFlags = []
    @State private var recordedKey: Key?

    var body: some View {
        Form {
            Section {
                LabeledContent("Input Device", value: "System Default")
                Button("Choose Microphone in Sound Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound?input") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } header: {
                Text("Microphone")
            }

            Section {
                if isRecordingHotkey {
                    HotKeyRecorderView(
                        isRecording: $isRecordingHotkey,
                        recordedModifiers: $recordedModifiers,
                        recordedKey: $recordedKey,
                        onComplete: { newHotkey in
                            globalHotkey = newHotkey
                            updateGlobalHotkey(newHotkey)
                        }
                    )
                } else {
                    HStack(spacing: 10) {
                        Text(globalHotkey)
                            .font(.system(.body, design: .monospaced))
                            .monospacedDigit()

                        Spacer()

                        Button("Change…") {
                            isRecordingHotkey = true
                            recordedModifiers = []
                            recordedKey = nil
                        }
                    }
                }
            } header: {
                Text("Global Hotkey")
            } footer: {
                Text("For a modifier key on its own, such as right ⌘, use the Press & Hold section below.")
            }

            Section {
                Toggle(isOn: $pressAndHoldEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Press & Hold")
                        Text("Hold a modifier key to control recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: pressAndHoldEnabled) { _, _ in
                    publishPressAndHoldConfiguration()
                }

                if pressAndHoldEnabled {
                    Picker("Behavior", selection: $pressAndHoldModeRaw) {
                        ForEach(PressAndHoldMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: pressAndHoldModeRaw) { _, _ in
                        publishPressAndHoldConfiguration()
                    }

                    Picker("Key", selection: $pressAndHoldKeyIdentifier) {
                        ForEach(PressAndHoldKey.allCases, id: \.rawValue) { key in
                            Text(key.displayName).tag(key.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: pressAndHoldKeyIdentifier) { _, _ in
                        publishPressAndHoldConfiguration()
                    }
                }
            } header: {
                Text("Press & Hold")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Requires Accessibility permission to work in other apps.")
                    Text(SetupPermissions.restartNote)
                    Button("Setup & Permissions…") { LocalSetupWindowController.shared.show(onContinue: {}) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func publishPressAndHoldConfiguration() {
        let selectedMode = PressAndHoldMode(rawValue: pressAndHoldModeRaw) ?? PressAndHoldConfiguration.defaults.mode
        let selectedKey = PressAndHoldKey(rawValue: pressAndHoldKeyIdentifier) ?? PressAndHoldConfiguration.defaults.key
        let configuration = PressAndHoldConfiguration(
            enabled: pressAndHoldEnabled,
            key: selectedKey,
            mode: selectedMode
        )
        NotificationCenter.default.post(name: .pressAndHoldSettingsChanged, object: configuration)
    }

    private func updateGlobalHotkey(_ newHotkey: String) {
        NotificationCenter.default.post(
            name: .updateGlobalHotkey,
            object: newHotkey
        )
    }
}

#Preview {
    DashboardRecordingView()
        .frame(width: 900, height: 700)
}
