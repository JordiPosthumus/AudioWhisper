import SwiftUI

internal struct DashboardPreferencesView: View {
    @AppStorage("immediateRecording") private var immediateRecording = false
    @AppStorage(AppDefaults.Keys.transcriptionStreaming) private var transcriptionStreaming = true
    @AppStorage(AppDefaults.Keys.addTrailingSpace) private var addTrailingSpace = true
    @AppStorage("autoBoostMicrophoneVolume") private var autoBoostMicrophoneVolume = false
    @AppStorage("playCompletionSound") private var playCompletionSound = true
    @AppStorage("transcriptionHistoryEnabled") private var transcriptionHistoryEnabled = false
    @AppStorage("transcriptionRetentionPeriod") private var transcriptionRetentionPeriodRaw = RetentionPeriod.oneMonth.rawValue



    private var retentionBinding: Binding<RetentionPeriod> {
        Binding(
            get: { RetentionPeriod(rawValue: transcriptionRetentionPeriodRaw) ?? .oneMonth },
            set: { transcriptionRetentionPeriodRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section("General") {
                LoginItemControlView()

                Toggle(isOn: $immediateRecording) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Express Mode")
                        Text("Hotkey immediately starts and stops recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $autoBoostMicrophoneVolume) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Boost Microphone")
                        Text("Temporarily maximize mic input while recording.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Paste", value: "Copied automatically; paste with ⌘V")

                Toggle(isOn: $addTrailingSpace) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Trailing Space")
                        Text("Add a space after sentence-ending punctuation so your next dictation pastes separately.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $transcriptionStreaming) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcription Streaming")
                        Text("Show live words while you speak. Changes apply to your next recording; the final pass always checks the complete audio.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $playCompletionSound) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Completion Sound")
                        Text("Play a chime when transcription finishes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

            }

            Section {
                Toggle(isOn: $transcriptionHistoryEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save Transcription History")
                        Text("Store transcripts locally so you can search and review them later.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if transcriptionHistoryEnabled {
                    Picker("Retention Period", selection: retentionBinding) {
                        ForEach(RetentionPeriod.allCases, id: \.rawValue) { period in
                            Text(period.displayName).tag(period)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("History")
            } footer: {
                Text("View saved transcripts in the Transcripts tab.")
            }

            Section("About") {
                Text("Built on the original AudioWhisper project.")
                    .foregroundStyle(.secondary)
                Link("AudioWhisper by mazdak and contributors", destination: URL(string: "https://github.com/mazdak/AudioWhisper")!)
                Text("Original MIT license and attribution retained.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Version") {
                    Text(VersionInfo.version)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

            }
        }
        .formStyle(.grouped)
    }


}

#Preview {
    DashboardPreferencesView()
        .frame(width: 900, height: 700)
}
