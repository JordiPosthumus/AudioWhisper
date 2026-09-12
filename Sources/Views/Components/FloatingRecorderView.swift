import SwiftUI

/// A live meter while speaking, then a persistent, explicit transcript review.
internal struct FloatingRecorderView: View {
    let status: AppStatus
    let audioLevel: Float
    let recordingStartedAt: Date?
    let transcript: String?
    let targetName: String?
    let message: String?
    let isPasting: Bool
    let onPrimaryAction: () -> Void
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onDismiss: () -> Void

    private let accent = Color(red: 0.20, green: 0.85, blue: 0.95)
    private var recording: Bool { if case .recording = status { return true }; return false }
    private var processing: Bool { if case .processing = status { return true }; return false }
    private var level: Double { AudioLevelDisplay.clamped(audioLevel) }
    private var size: CGSize {
        transcript.map { RecorderWindowGeometry.previewSize(text: $0, message: message) } ?? LayoutMetrics.RecordingWindow.size
    }

    var body: some View {
        Group {
            if let transcript { preview(transcript) }
            else { recordingBar }
        }
        .frame(width: size.width, height: size.height)
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

    private func preview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "waveform")
                    .foregroundStyle(accent)
                Text("Ready to paste")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                closeButton
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(accent)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button(action: onCopy) { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(.bordered)
                    .disabled(isPasting)
                Spacer()
                Button(action: onPaste) {
                    HStack(spacing: 7) {
                        if isPasting { ProgressView().controlSize(.mini) }
                        Text(isPasting ? "Pasting…" : "Paste")
                        if !isPasting { Image(systemName: "return") }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .disabled(isPasting)
                .help(targetName.map { "Paste into \($0)" } ?? "Paste into the app you were using")
            }
            .controlSize(.regular)

            Text(targetName.map { "To \($0) · Enter to paste · Esc to dismiss" } ?? "Enter to paste · Esc to dismiss")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(1)
        }
        .padding(16)
        .foregroundStyle(.white)
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
