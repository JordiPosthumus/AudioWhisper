import SwiftUI

/// A compact live meter. Completed transcripts go to the clipboard and the HUD hides.
internal struct FloatingRecorderView: View {
    let status: AppStatus
    let audioLevel: Float
    let recordingStartedAt: Date?
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    private let accent = Color(red: 0.20, green: 0.85, blue: 0.95)
    private var recording: Bool { if case .recording = status { return true }; return false }
    private var processing: Bool { if case .processing = status { return true }; return false }
    private var level: Double { AudioLevelDisplay.clamped(audioLevel) }
    var body: some View {
        recordingBar
        .frame(width: LayoutMetrics.RecordingWindow.size.width, height: LayoutMetrics.RecordingWindow.size.height)
        .background(Color(red: 0.055, green: 0.075, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: LayoutMetrics.RecordingWindow.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: LayoutMetrics.RecordingWindow.cornerRadius, style: .continuous)
            .stroke(.white.opacity(0.15), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private var recordingBar: some View {
        HStack(spacing: 12) {
            Button(action: onPrimaryAction) {
                AudioLevelOrb(level: recording ? level : 0, recording: recording, processing: processing)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .disabled(processing)
            .help(recording ? "Stop recording" : "Start recording")
            .accessibilityLabel(recording ? "Stop recording" : "Start recording")

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(recording ? "Listening" : processing ? "Transcribing" : "SpeedyWhisper")
                        .font(.system(size: 12, weight: .semibold))
                    if recording, let recordingStartedAt {
                        Text(recordingStartedAt, style: .timer)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                if recording {
                    HStack(spacing: 3) {
                        ForEach(0..<12, id: \.self) { index in
                            Capsule()
                                .fill(AudioLevelDisplay.isLit(index: index, count: 12, level: level) ? accent : .white.opacity(0.13))
                                .frame(width: 4, height: 7)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Microphone level")
                    .accessibilityValue("\(Int(level * 100)) percent")
                } else {
                    Text(processing ? "Local transcription…" : "Click to record")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.white)

            closeButton
        }
        .padding(.horizontal, 11)
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 20, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Dismiss (Esc)")
        .accessibilityLabel("Dismiss recorder")
    }
}

internal enum AudioLevelDisplay {
    static func clamped(_ value: Float) -> Double {
        guard value.isFinite else { return 0 }
        return Double(min(1, max(0, value)))
    }

    static func isLit(index: Int, count: Int, level: Double) -> Bool {
        level > Double(index) / Double(count)
    }
}

private struct AudioLevelOrb: View {
    let level: Double
    let recording: Bool
    let processing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.08, green: 0.18, blue: 0.25))
            Circle()
                .stroke(Color.cyan.opacity(recording ? 0.3 + level * 0.7 : 0.25), lineWidth: recording ? 1.5 + level * 3 : 1.5)
                .padding(2)
            Circle()
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 24, height: 24)
                .scaleEffect(recording ? 0.72 + level * 0.38 : 0.82)
                .opacity(recording ? 0.55 + level * 0.45 : 0.85)
            if processing {
                ProgressView().controlSize(.small).tint(.white)
            } else {
                Image(systemName: recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: recording ? 9 : 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: level)
        .accessibilityHidden(true)
    }
}
