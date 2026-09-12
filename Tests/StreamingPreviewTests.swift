import XCTest
import AVFoundation
@testable import AudioWhisper

@MainActor
final class StreamingPreviewTests: XCTestCase {
    func testStreamingDefaultsOnButPreservesAnExplicitOffSetting() throws {
        let name = "StreamingSettingsTests.\(UUID())"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { preferences.removePersistentDomain(forName: name) }
        XCTAssertTrue(AppDefaults.streamingEnabled(in: preferences))
        preferences.set(false, forKey: AppDefaults.Keys.transcriptionStreaming)
        let reopened = try XCTUnwrap(UserDefaults(suiteName: name))
        XCTAssertFalse(AppDefaults.streamingEnabled(in: reopened))
    }

    func testFinalScanDurationScalesWithoutLeavingAPersistentPanel() {
        let short = TranscriptPresentation.duration(for: "Thank you.")
        let longer = TranscriptPresentation.duration(for: String(repeating: "word ", count: 40))
        let longest = TranscriptPresentation.duration(for: String(repeating: "word ", count: 1000))
        XCTAssertLessThan(short, longer)
        XCTAssertLessThan(longer, longest)
        XCTAssertLessThanOrEqual(longest, 6)
        XCTAssertGreaterThanOrEqual(short, 0.85)
    }

    func testDisabledStreamingNeverStartsCaptureOrRequestsModel() async throws {
        let daemon = MLDaemonManager()
        let requests = PreviewRequestLog()
        await daemon.setTestResponder { method, _ in requests.add(method); return ["success": true] }
        let capture = FakePreviewCapture()
        let preview = StreamingPreviewCoordinator(capture: capture, daemon: daemon, allowsCapture: true)
        preview.start(enabled: false)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(capture.starts, 0)
        XCTAssertTrue(requests.values.isEmpty)
        XCTAssertFalse(preview.isEnabledForSession)
        await daemon.shutdown()
    }

    func testLiveWordsStopUpdatingWhenRecordingStops() async throws {
        let daemon = MLDaemonManager()
        let requests = PreviewRequestLog()
        await daemon.setTestResponder { method, params in
            requests.add(method)
            if method == "preview_audio" {
                XCTAssertEqual(params["sequence"] as? Int, 0)
                return ["active": true, "stable": "Live ", "draft": "words"]
            }
            return ["success": true]
        }
        let capture = FakePreviewCapture()
        let preview = StreamingPreviewCoordinator(capture: capture, daemon: daemon, allowsCapture: true)
        preview.start(enabled: true)
        let oldCallback = capture.onPCM
        capture.emit(Data(repeating: 0, count: 51_200))
        try await until { preview.draftText == "words" }
        XCTAssertEqual(preview.stableText, "Live ")
        preview.stop()
        oldCallback?(Data(repeating: 0, count: 51_200))
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(requests.values.filter { $0 == "preview_audio" }.count, 1)
        XCTAssertEqual(preview.draftText, "words", "Draft stays visible while the final pass runs")
        await daemon.shutdown()
    }

    func testPreviewFailureLeavesFinalTranscriptionAvailable() async throws {
        let daemon = MLDaemonManager()
        await daemon.setTestResponder { method, _ in
            if method == "preview_audio" { throw MLDaemonError.remoteError("preview failure") }
            if method == "transcribe" { return ["success": true, "text": "Complete final text"] }
            return ["success": true]
        }
        let capture = FakePreviewCapture()
        let preview = StreamingPreviewCoordinator(capture: capture, daemon: daemon, allowsCapture: true)
        preview.start(enabled: true)
        capture.emit(Data(repeating: 0, count: 51_200))
        try await until { preview.problem != nil }
        XCTAssertNil(capture.onPCM)
        let final = try await daemon.transcribe(repo: "unchanged", pcmPath: "/tmp/not-read-by-fake")
        XCTAssertEqual(final, "Complete final text")
        await daemon.shutdown()
    }

    func testOldAudioCallbacksCannotContaminateNextRecording() async throws {
        let daemon = MLDaemonManager()
        let requests = PreviewRequestLog()
        await daemon.setTestResponder { method, _ in
            requests.add(method)
            if method == "preview_audio" { return ["active": true, "stable": "", "draft": "new session"] }
            return ["success": true]
        }
        let capture = FakePreviewCapture()
        let preview = StreamingPreviewCoordinator(capture: capture, daemon: daemon, allowsCapture: true)
        preview.start(enabled: true)
        let oldCallback = capture.onPCM
        preview.start(enabled: true)
        oldCallback?(Data(repeating: 0, count: 51_200))
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(requests.values.contains("preview_audio"))
        capture.emit(Data(repeating: 0, count: 51_200))
        try await until { preview.draftText == "new session" }
        preview.stop()
        await daemon.shutdown()
    }

    func testConverterHandlesContinuousStereoAndMonoAtNativeRates() throws {
        for rate in [44_100.0, 48_000.0] {
            for channels: AVAudioChannelCount in [1, 2] {
                let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: channels, interleaved: false))
                let converter = try PreviewPCMConverter(inputFormat: format)
                var result = Data()
                var position = 0
                while position < Int(rate) {
                    let count = min(4096, Int(rate) - position)
                    let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
                    buffer.frameLength = AVAudioFrameCount(count)
                    for channel in 0..<Int(channels) {
                        for index in 0..<count {
                            buffer.floatChannelData![channel][index] = Float(sin(Double(position + index) * 2 * .pi * 440 / rate) * 0.2)
                        }
                    }
                    result.append(try converter.convert(buffer))
                    position += count
                }
                let samples = result.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
                XCTAssertEqual(Double(samples.count), 16_000, accuracy: 80)
                XCTAssertTrue(samples.allSatisfy { $0.isFinite })
                let rms = sqrt(samples.reduce(0) { $0 + Double($1 * $1) } / Double(samples.count))
                XCTAssertEqual(rms, 0.1414, accuracy: 0.02)
            }
        }
    }

    private func until(_ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(condition(), "Timed out waiting for preview state")
    }
}

@MainActor
final class FakePreviewCapture: PreviewAudioCapturing {
    var starts = 0
    var onPCM: (@Sendable (Data) -> Void)?
    func start(onPCM: @escaping @Sendable (Data) -> Void, onFailure: @escaping @Sendable () -> Void) throws {
        starts += 1
        self.onPCM = onPCM
    }
    func stop() { onPCM = nil }
    func emit(_ data: Data) { onPCM?(data) }
}

private final class PreviewRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []
    var values: [String] { lock.withLock { entries } }
    func add(_ method: String) { lock.withLock { entries.append(method) } }
}
