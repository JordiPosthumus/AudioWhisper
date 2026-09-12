import XCTest
import AVFoundation
import AudioToolbox
@testable import AudioWhisper

final class AudioProcessorTests: XCTestCase {
    func testLoadAudioReadsSamplesVerbatimAtSameRate() throws {
        let originalSamples: [Float] = [0, 0.25, -0.25, 0.75, -0.75]
        let url = try makeTempAudioFile(samples: originalSamples, sampleRate: 48_000)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try loadAudio(url: url, samplingRate: 48_000)

        XCTAssertEqual(loaded.count, originalSamples.count)
        zip(loaded, originalSamples).forEach { loadedSample, expected in
            XCTAssertEqual(loadedSample, expected, accuracy: 0.0001)
        }
    }

    func testLoadAudioResamplesToRequestedRate() throws {
        let duration: Double = 0.05 // seconds
        let sourceRate: Double = 24_000
        let targetRate = 48_000
        let frameCount = Int(sourceRate * duration)
        let sineWave = (0..<frameCount).map { index -> Float in
            let theta = Double(index) / sourceRate * 2 * Double.pi * 440
            return Float(sin(theta))
        }

        let url = try makeTempAudioFile(samples: sineWave, sampleRate: sourceRate)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try loadAudio(url: url, samplingRate: targetRate)

        let expectedFrames = Int(duration * Double(targetRate))
        XCTAssertLessThanOrEqual(abs(loaded.count - expectedFrames), 4, "Resampled frame count should match target rate within tolerance")
        XCTAssertNotEqual(loaded.prefix(10).reduce(0, +), 0, "Resampled data should retain non-zero content")
    }

    func testLoadAudioThrowsOpenFailedForMissingFile() {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).wav")

        XCTAssertThrowsError(try loadAudio(url: url, samplingRate: 44_100)) { error in
            guard case let AudioLoadError.openFailed(status) = error else {
                return XCTFail("Expected openFailed error")
            }
            XCTAssertNotEqual(status, noErr)
        }
    }

    func testStreamedPCMMatchesDecodedSamplesAcrossMultipleChunks() throws {
        let samples = (0..<400_003).map { Float(sin(Double($0) * 0.03)) }
        let input = try makeTempAudioFile(samples: samples, sampleRate: 48_000)
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: output)
        }
        let expected = try loadAudio(url: input, samplingRate: 16_000)
        try writeAudioPCM(url: input, to: output, samplingRate: 16_000)
        XCTAssertEqual(try Data(contentsOf: output), expected.withUnsafeBytes { Data($0) })
    }

    func testStreamingFailureRemovesPartialOutput() throws {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertThrowsError(try writeAudioPCM(
            url: URL(fileURLWithPath: "/missing/\(UUID().uuidString)"),
            to: output, samplingRate: 16_000
        ))
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }

    func testInvalidSampleRateIsRejected() throws {
        let url = try makeTempAudioFile(samples: [0, 1, 0], sampleRate: 16_000)
        defer { try? FileManager.default.removeItem(at: url) }
        for rate in [0, -1] {
            XCTAssertThrowsError(try loadAudio(url: url, samplingRate: rate)) { error in
                guard case AudioLoadError.unsupportedFormat = error else {
                    return XCTFail("Expected unsupportedFormat, got \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeTempAudioFile(samples: [Float], sampleRate: Double) throws -> URL {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channel = buffer.floatChannelData?[0] {
            for (index, sample) in samples.enumerated() {
                channel[index] = sample
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
