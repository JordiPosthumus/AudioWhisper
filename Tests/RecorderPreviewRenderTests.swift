import XCTest
import SwiftUI
import AppKit
@testable import AudioWhisper

/// Opt-in render fixture; never opens a live window or records audio.
@MainActor
final class RecorderPreviewRenderTests: XCTestCase {
    func testRenderRecorderAndPreview() throws {
        guard let destination = ProcessInfo.processInfo.environment["SPEEDYWHISPER_PREVIEW_DIR"] else {
            throw XCTSkip("Set SPEEDYWHISPER_PREVIEW_DIR to render the recorder states")
        }
        let directory = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recording = FloatingRecorderView(status: .recording, audioLevel: 0.7, recordingStartedAt: nil,
            transcript: nil, targetName: nil, message: nil, isPasting: false,
            onPrimaryAction: {}, onCopy: {}, onPaste: {}, onDismiss: {})
        let preview = FloatingRecorderView(status: .success, audioLevel: 0, recordingStartedAt: nil,
            transcript: "SpeedyWhisper keeps dictation simple. Speak, review your words, then press Enter to paste.",
            targetName: "TextEdit", message: nil, isPasting: false,
            onPrimaryAction: {}, onCopy: {}, onPaste: {}, onDismiss: {})
        try render(recording, to: directory.appendingPathComponent("recorder.png"), size: LayoutMetrics.RecordingWindow.size)
        try render(preview, to: directory.appendingPathComponent("preview.png"), size: RecorderWindowGeometry.previewSize(text: preview.transcript!, message: nil))
    }

    private func render<V: View>(_ view: V, to url: URL, size: CGSize) throws {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
    }
}
