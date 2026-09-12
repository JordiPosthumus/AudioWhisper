import XCTest
@testable import AudioWhisper

/// Opt-in integration against an existing offline runtime/model. No microphone or clipboard writes.
@MainActor
final class StreamingRealModelTests: XCTestCase {
    func testRealStreamingPreviewAndUnchangedFinalPass() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let python = environment["SPEEDYWHISPER_MODEL_TEST_PYTHON"],
              let input = environment["SPEEDYWHISPER_MODEL_TEST_AUDIO"] else {
            throw XCTSkip("Set existing Python and raw PCM paths to run the offline model integration")
        }
        let sourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let daemon = MLDaemonManager()
        await daemon.setTestOverrides(python: URL(fileURLWithPath: python), script: sourceRoot.appendingPathComponent("Sources/ml_daemon.py"))
        do {
            let baseline = try await daemon.transcribe(repo: ParakeetModel.v2English.rawValue, pcmPath: input)
            let pid = await daemon.processIdentifierForTesting
            XCTAssertFalse(baseline.isEmpty)
            let capture = FakePreviewCapture()
            let preview = StreamingPreviewCoordinator(capture: capture, daemon: daemon, allowsCapture: true)
            let pcm = try Data(contentsOf: URL(fileURLWithPath: input))
            XCTAssertGreaterThan(pcm.count, 51_200)
            preview.start(enabled: true)
            capture.emit(Data(pcm.prefix(51_200)))
            let deadline = Date().addingTimeInterval(20)
            while preview.stableText.isEmpty && preview.draftText.isEmpty && preview.problem == nil && Date() < deadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertNil(preview.problem)
            XCTAssertFalse((preview.stableText + preview.draftText).isEmpty, "Words must arrive before the complete recording")
            XCTAssertNotEqual(preview.stableText + preview.draftText, baseline)
            let initial = preview.stableText + preview.draftText
            capture.emit(Data(pcm.dropFirst(51_200).prefix(51_200)))
            let nextDeadline = Date().addingTimeInterval(20)
            while preview.stableText + preview.draftText == initial && preview.problem == nil && Date() < nextDeadline {
                try await Task.sleep(for: .milliseconds(20))
            }
            XCTAssertNil(preview.problem)
            XCTAssertNotEqual(preview.stableText + preview.draftText, initial)
            XCTAssertFalse((preview.stableText + preview.draftText).isEmpty, "The second packet must not erase the early draft")
            preview.stop()
            // Replaying short speech packet by packet must converge to the normal
            // decoder's words. The former streaming approximation fails this check.
            let qualitySession = UUID()
            try await daemon.startPreview(sessionID: qualitySession)
            var draft = ""
            for (sequence, offset) in stride(from: 0, to: pcm.count, by: 51_200).enumerated() {
                let result = try await daemon.appendPreview(sessionID: qualitySession, sequence: sequence,
                    pcm: Data(pcm[offset..<min(offset + 51_200, pcm.count)]))
                draft = result.stable + result.draft
            }
            if pcm.count <= 16_000 * 4 * 8 {
                XCTAssertEqual(draft, baseline, "A short live draft must converge to full-attention decoding")
            }
            await daemon.endPreview(sessionID: qualitySession)
            let final = try await daemon.transcribe(repo: ParakeetModel.v2English.rawValue, pcmPath: input)
            XCTAssertEqual(final, baseline)
            let finalPID = await daemon.processIdentifierForTesting
            XCTAssertEqual(finalPID, pid, "Streaming must reuse the existing daemon/model")
            await daemon.shutdown()
        } catch {
            await daemon.shutdown()
            throw error
        }
    }
}
