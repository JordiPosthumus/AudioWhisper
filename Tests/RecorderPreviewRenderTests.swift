import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

/// Opt-in offscreen renders; fixture meter samples are never used in the application.
@MainActor
final class RecorderPreviewRenderTests: XCTestCase {
    func testRenderFirstRunSetup() async throws {
        guard let destination = ProcessInfo.processInfo.environment["SPEEDYWHISPER_PREVIEW_DIR"] else {
            throw XCTSkip("Set SPEEDYWHISPER_PREVIEW_DIR for setup renders")
        }
        let directory = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let waiting = LocalSetupManager(supported: true, existingInstallation: { false })
        let ready = LocalSetupManager(supported: true, existingInstallation: { true })
        let failed = LocalSetupManager(supported: true, existingInstallation: { false },
            runtime: { throw URLError(.notConnectedToInternet) })
        await failed.prepare()
        for (name, setup) in [("setup", waiting), ("setup-ready", ready), ("setup-error", failed)] {
            let view = LocalSetupView(setup: setup, onContinue: {})
            let host = NSHostingView(rootView: view)
            try render(view, to: directory.appendingPathComponent(name + ".png"), size: host.fittingSize)
        }
    }

    func testRenderRecorderAndPreview() throws {
        guard let destination = ProcessInfo.processInfo.environment["SPEEDYWHISPER_PREVIEW_DIR"] else {
            throw XCTSkip("Set SPEEDYWHISPER_PREVIEW_DIR to render the recorder states")
        }
        let directory = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let meter = RecorderMeterFixture()
        let showcaseStable = "Capture the thought while it’s still fresh. Speak naturally, watch your words appear, and keep your attention on what you want to say.\n\n"
        let showcaseDraft = "Your voice stays on your Mac. When you’re finished, the complete transcript is ready to paste wherever you’re working."
        try render(FloatingRecorderView(status: .recording, audioLevel: 0.68,
            recordingStartedAt: Date().addingTimeInterval(-18),
            waveformSamples: (0..<48).map { Float(0.48 + sin(Double($0) * 0.32) * 0.20) },
            stableText: showcaseStable, draftText: showcaseDraft, streaming: true,
            onPrimaryAction: {}, onDismiss: {}),
            to: directory.appendingPathComponent("showcase.png"),
            size: TranscriptPresentation.size(finalText: nil, live: true, liveText: showcaseStable + showcaseDraft))
        try render(RecorderStreamingFixture(meter: meter), to: directory.appendingPathComponent("streaming.png"),
                   size: TranscriptPresentation.size(finalText: nil, live: true), meter: meter)
        let processing = FloatingRecorderView(status: .processing("Transcribing"), audioLevel: 0, recordingStartedAt: nil,
            stableText: "Let’s keep dictation simple, ", draftText: "and make every word count.", streaming: true,
            onPrimaryAction: {}, onDismiss: {})
        try render(processing, to: directory.appendingPathComponent("processing.png"), size: TranscriptPresentation.size(finalText: nil, live: true))
        let text = "Let’s keep dictation simple, and make every word count."
        let complete = FloatingRecorderView(status: .success, audioLevel: 0, recordingStartedAt: nil,
            finalText: text, onPrimaryAction: {}, onDismiss: {})
        try render(complete, to: directory.appendingPathComponent("complete.png"), size: TranscriptPresentation.size(finalText: text, live: false))
        let longText = String(repeating: "A beautiful, quiet space for your words. Speak naturally and let the final pass bring everything together. ", count: 6)
        try render(FloatingRecorderView(status: .success, audioLevel: 0, recordingStartedAt: nil, finalText: longText, onPrimaryAction: {}, onDismiss: {}),
                   to: directory.appendingPathComponent("complete-long.png"), size: TranscriptPresentation.size(finalText: longText, live: false))
        let paragraph = String(repeating: "The transcript grows with the conversation, keeping complete thoughts visible beside the familiar voice display. ", count: 15)
        try render(FloatingRecorderView(status: .recording, audioLevel: 0.7, recordingStartedAt: Date().addingTimeInterval(-65),
            waveformSamples: Array(repeating: 0.7, count: 48), stableText: String(paragraph.dropLast(120)), draftText: String(paragraph.suffix(120)), streaming: true, onPrimaryAction: {}, onDismiss: {}),
            to: directory.appendingPathComponent("streaming-long.png"),
            size: TranscriptPresentation.size(finalText: nil, live: true, liveText: paragraph))
        let hugeText = String(repeating: paragraph, count: 8)
        let smallerScreen = CGSize(width: 800, height: 600)
        try render(FloatingRecorderView(status: .success, audioLevel: 0, recordingStartedAt: nil,
            finalText: hugeText, availableSize: smallerScreen, onPrimaryAction: {}, onDismiss: {}),
            to: directory.appendingPathComponent("complete-overflow.png"),
            size: TranscriptPresentation.size(finalText: hugeText, live: false, available: smallerScreen))
        let offline = FloatingRecorderView(status: .recording, audioLevel: 0, recordingStartedAt: nil, onPrimaryAction: {}, onDismiss: {})
        try render(offline, to: directory.appendingPathComponent("streaming-off.png"), size: TranscriptPresentation.size(finalText: nil, live: false))
    }

    private func render<V: View>(_ view: V, to url: URL, size: CGSize, meter: RecorderMeterFixture? = nil) throws {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if let meter {
            for index in 0..<48 {
                meter.level = Float(max(0, sin(Double(index) * 0.33) * 0.28 + sin(Double(index) * 0.71) * 0.23 + 0.40))
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
}

@MainActor
private final class RecorderMeterFixture: ObservableObject {
    @Published var level: Float = 0
}

private struct RecorderStreamingFixture: View {
    @ObservedObject var meter: RecorderMeterFixture
    let started = Date().addingTimeInterval(-12)
    var body: some View {
        FloatingRecorderView(status: .recording, audioLevel: meter.level, recordingStartedAt: started,
            waveformSamples: (0..<48).map { index in Float(max(0, sin(Double(index) * 0.33) * 0.28 + sin(Double(index) * 0.71) * 0.23 + 0.40)) },
            stableText: "Let’s keep dictation simple, ", draftText: "and make every word count.", streaming: true,
            onPrimaryAction: {}, onDismiss: {})
    }
}
