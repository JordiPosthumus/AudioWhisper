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
                    .frame(height: 37)
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

internal struct VoiceRibbon: View {
    let levels: [Double]
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if active && !reduceMotion {
                // Redraw only this small canvas. No particles, blur passes, or
                // perpetual work once recording stops. Audio still meters at 10 Hz.
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    scanner(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                scanner(at: nil)
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Microphone waveform")
    }

    private func scanner(at time: TimeInterval?) -> some View {
        Canvas { context, size in
            let count = 32
            let pitch = size.width / Double(count)
            let phase = (time ?? 0) * (2 * Double.pi / 3.2)
            let head = time == nil ? 0.5 : 0.5 + 0.46 * sin(phase)
            let direction = cos(phase) >= 0 ? 1.0 : -1.0
            let voice = active ? (levels.suffix(6).max() ?? 0) : 0
            let red = Color(red: 1, green: 0.08, blue: 0.12)
            let lamp = Gradient(colors: [
                Color(red: 1, green: 0.30, blue: 0.25), red, Color(red: 0.60, green: 0.015, blue: 0.08)
            ])

            // A gradient supplies the halo without an offscreen blur texture.
            if active {
                let center = CGPoint(x: head * size.width, y: size.height / 2)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 55, y: center.y - 18, width: 110, height: 36)),
                    with: .radialGradient(Gradient(colors: [red.opacity(0.11 + voice * 0.10), .clear]),
                        center: center, startRadius: 0, endRadius: 55))
            }

            for index in 0..<count {
                let position = (Double(index) + 0.5) / Double(count)
                let distance = abs(position - head)
                let behind = (head - position) * direction >= 0
                let core = exp(-pow(distance * 21, 2))
                let trail = exp(-distance * (behind ? 14 : 48))
                let scanner = active ? min(1, core * 0.8 + trail * 0.4) : 0
                let sampleIndex = min(levels.count - 1, index * levels.count / count)
                let level = active && sampleIndex >= 0 ? levels[sampleIndex] : 0
                // Height is driven only by captured voice levels; the scanner is light.
                let height = 4 + pow(level, 1.4) * (size.height - 10)
                let rect = CGRect(x: Double(index) * pitch + 1.6, y: (size.height - height) / 2,
                                  width: max(1, pitch - 3.2), height: height)
                let shape = Path(roundedRect: rect, cornerRadius: 1.5)
                var segment = context
                segment.opacity = active ? min(0.96, 0.10 + scanner * (0.61 + voice * 0.24) + level * 0.12) : 0.05
                segment.fill(shape, with: .linearGradient(lamp,
                    startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                if scanner > 0.3 {
                    let filament = CGRect(x: rect.minX + 1, y: rect.midY - 0.7,
                                          width: max(1, rect.width - 2), height: 1.4)
                    context.fill(Path(roundedRect: filament, cornerRadius: 0.7),
                        with: .color(Color(red: 1, green: 0.72, blue: 0.56).opacity(scanner * (0.35 + voice * 0.5))))
                }
            }
        }
    }
}
