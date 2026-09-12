import SwiftUI

/// Voice-driven feedback, provisional live words, and a self-dismissing clipboard confirmation.
internal struct FloatingRecorderView: View {
    let status: AppStatus
    let audioLevel: Float
    let recordingStartedAt: Date?
    var waveformSamples: [Float] = []
    var stableText = ""
    var draftText = ""
    var streaming = false
    var preparingPreview = false
    var previewProblem: String?
    var finalText: String?
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var completionGlow = false
    private let cyan = Color(red: 0.30, green: 0.91, blue: 0.97)
    private let lilac = Color(red: 0.65, green: 0.53, blue: 1)
    private var recording: Bool { if case .recording = status { return true }; return false }
    private var processing: Bool { if case .processing = status { return true }; return false }
    private var size: CGSize { TranscriptPresentation.size(finalText: finalText, live: streaming) }
    private var hasLiveWords: Bool { !(stableText + draftText).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var levels: [Double] {
        if reduceMotion { return Array(repeating: AudioLevelDisplay.clamped(audioLevel), count: 48) }
        return waveformSamples.isEmpty ? Array(repeating: 0, count: 48) : waveformSamples.map(AudioLevelDisplay.clamped)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 19).padding(.top, 15)
            if let finalText {
                finalTranscript(finalText)
            } else {
                VoiceRibbon(levels: levels, active: recording)
                    .frame(height: 51)
                    .padding(.horizontal, 20)
                    .padding(.top, 9)
                    .padding(.bottom, streaming ? 9 : 12)
                if streaming { liveTranscript }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color(red: 0.035, green: 0.050, blue: 0.083))
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(LinearGradient(colors: [lilac.opacity(0.12), .clear, cyan.opacity(completionGlow ? 0.19 : 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(LinearGradient(colors: [cyan.opacity(completionGlow ? 0.8 : 0.32), .white.opacity(0.06), lilac.opacity(0.38)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .environment(\.colorScheme, .dark)
        .onChange(of: finalText) { _, text in animateCompletion(text != nil) }
        .onAppear { if finalText != nil { animateCompletion(true) } }
    }

    private func animateCompletion(_ complete: Bool) {
        completionGlow = false
        guard complete else { return }
        if reduceMotion { completionGlow = true }
        else { withAnimation(.easeOut(duration: 0.4)) { completionGlow = true } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onPrimaryAction) {
                ZStack {
                    Circle().fill(cyan.opacity(finalText == nil ? 0.09 : 0.17))
                    Circle().stroke(cyan.opacity(0.25), lineWidth: 1)
                    Image(systemName: finalText != nil ? "checkmark" : recording ? "stop.fill" : "waveform")
                        .font(.system(size: finalText != nil ? 13 : 11, weight: .bold))
                        .foregroundStyle(cyan)
                        .scaleEffect(finalText != nil && !completionGlow && !reduceMotion ? 0.6 : 1)
                }
                .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .disabled(processing || finalText != nil)
            .help(recording ? "Stop recording" : "Start recording")
            .accessibilityLabel(finalText != nil ? "Copied" : recording ? "Stop recording" : "Start recording")
            VStack(alignment: .leading, spacing: 3) {
                Text(finalText != nil ? "Copied" : recording ? "Listening" : processing ? "Finalizing" : "SpeedyWhisper")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Text(finalText != nil ? "Ready for ⌘V" : processing ? "Checking the complete recording" : streaming ? "LOCAL · LIVE DICTATION" : "LOCAL DICTATION")
                    .font(.system(size: finalText != nil || processing ? 10 : 8, weight: .medium, design: .rounded))
                    .tracking(finalText != nil || processing ? 0 : 1.2)
                    .foregroundStyle(.white.opacity(0.43))
            }
            Spacer(minLength: 8)
            if recording, let recordingStartedAt {
                Text(recordingStartedAt, style: .timer)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(cyan.opacity(0.8))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(cyan.opacity(0.06), in: Capsule())
            } else if processing { ProgressView().controlSize(.small).tint(cyan) }
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 20, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel("Dismiss recorder")
        }
    }

    private var liveTranscript: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(LinearGradient(colors: [.white.opacity(0.02), .white.opacity(0.13), .white.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            if hasLiveWords {
                let tail = TranscriptPresentation.liveTail(stable: stableText, draft: draftText)
                (Text(tail.stable).foregroundColor(.white.opacity(0.92)) + Text(tail.draft).foregroundColor(cyan.opacity(0.8)))
                    .font(.system(size: 14)).lineSpacing(3).lineLimit(2).truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(previewProblem ?? (preparingPreview ? "Preparing live words…" : processing ? "Your final text is on its way…" : "Your words will appear here…"))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.36)).lineLimit(2)
            }
            if previewProblem != nil, hasLiveWords {
                Text("Live preview paused · final transcription continues")
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 20)
    }

    private func finalTranscript(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                Text(text).font(.system(size: 15)).lineSpacing(3)
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden).frame(maxHeight: .infinity)
            Capsule()
                .fill(LinearGradient(colors: [cyan.opacity(0.12), cyan, lilac.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 2)
                .scaleEffect(x: completionGlow ? 1 : 0, y: 1, anchor: .leading)
        }
        .padding(.horizontal, 20).padding(.top, 15).padding(.bottom, 17)
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

/// Three centered LED columns inspired by KITT's dashboard voice modulator.
/// This view updates only with the existing microphone meter; it has no clock.
internal struct VoiceRibbon: View {
    let levels: [Double]
    let active: Bool

    private func recentLevel(_ count: Int) -> Double {
        let samples = levels.suffix(count)
        guard active, !samples.isEmpty else { return 0 }
        return min(1, max(0, samples.reduce(0, +) / Double(samples.count)))
    }

    var body: some View {
        Canvas { context, size in
            let rows = 20
            let columnWidth = 18.0
            let gap = 7.0
            let width = columnWidth * 3 + gap * 2
            let origin = (size.width - width) / 2
            let pitch = (size.height - 2) / Double(rows)
            let red = Color(red: 1, green: 0.065, blue: 0.09)
            let voice = recentLevel(1)
            // Center follows the present syllable; the flanks use a short envelope
            // of real readings. These are visual envelopes, not frequency bands.
            let envelopes = [recentLevel(2) * 0.76, voice, recentLevel(3) * 0.76]
            let lamp = Gradient(colors: [Color(red: 1, green: 0.31, blue: 0.22), red,
                                         Color(red: 0.75, green: 0.015, blue: 0.055)])

            // Fine, stationary rails frame the voice box without filling the width.
            for side in [0, 1] {
                let x = side == 0 ? origin - 10 : origin + width + 9
                context.fill(Path(CGRect(x: x, y: 1, width: 1, height: size.height - 2)),
                             with: .color(red.opacity(0.10)))
            }
            for column in 0..<3 {
                let strength = pow(envelopes[column], 1.1)
                let litPairs = Int((strength * Double(rows / 2)).rounded())
                let x = origin + Double(column) * (columnWidth + gap)
                if litPairs > 0 {
                    let center = CGPoint(x: x + columnWidth / 2, y: size.height / 2)
                    context.fill(Path(ellipseIn: CGRect(x: x - 9, y: 0, width: columnWidth + 18, height: size.height)),
                        with: .radialGradient(Gradient(colors: [red.opacity(strength * 0.15), .clear]),
                            center: center, startRadius: 0, endRadius: size.height / 2))
                }
                for row in 0..<rows {
                    let distance = abs(Double(row) - Double(rows - 1) / 2)
                    let lit = distance < Double(litPairs)
                    let rect = CGRect(x: x, y: 1 + Double(row) * pitch,
                                      width: columnWidth, height: max(1, pitch - 0.8))
                    var light = context
                    light.opacity = lit ? 0.76 + strength * 0.24 : 0.045
                    light.fill(Path(roundedRect: rect, cornerRadius: 0.35), with: .linearGradient(lamp,
                        startPoint: CGPoint(x: rect.midX, y: rect.minY),
                        endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                }
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Microphone voice level")
    }
}
