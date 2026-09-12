import XCTest
import Alamofire
import AVFoundation
@testable import AudioWhisper

private final class GeminiStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body: String
        if request.url?.path == "/upload/v1beta/files" {
            body = #"{"file":{"uri":"https://example.invalid/file","name":"files/test"}}"#
        } else {
            // Echo how audio was sent, proving the actual request passed through the right branch.
            let data: Data
            if let body = request.httpBody {
                data = body
            } else if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var collected = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    collected.append(contentsOf: buffer.prefix(count))
                }
                data = collected
            } else { data = Data() }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let contents = json?["contents"] as? [[String: Any]]
            let parts = contents?.first?["parts"] as? [[String: Any]]
            let audio = parts?.first
            let mode = audio?["file_data"] != nil ? "file" : "inline"
            let payload = (audio?["file_data"] ?? audio?["inline_data"]) as? [String: Any]
            let mime = payload?["mime_type"] as? String ?? "missing"
            body = #"{"candidates":[{"content":{"parts":[{"text":"\#(mode) \#(mime)"}]}}]}"#
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class GeminiUploadRoutingTests: XCTestCase {
    func testSixMegabyteFileUsesFilesAPIInsteadOfFailingInlineLimit() async throws {
        try await assertRoute(frames: 1_600_000, expected: "file audio/wav")
    }

    func testSmallWAVUsesInlineDataWithCorrectMIMEType() async throws {
        try await assertRoute(frames: 1000, expected: "inline audio/wav")
    }

    private func assertRoute(frames: UInt32, expected: String) async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GeminiStubProtocol.self]
        let session = Session(configuration: config)
        let keys = MockKeychainService()
        keys.saveQuietly("test-key", service: "AudioWhisper", account: "Gemini")
        let suite = "GeminiRouting.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("https://example.invalid", forKey: "geminiBaseURL")
        let service = SpeechToTextService(keychainService: keys, defaults: defaults, session: session)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try makeAudio(at: url, frames: frames)
        let result = try await service.transcribeRaw(audioURL: url, provider: .gemini)
        XCTAssertEqual(result, expected)
    }

    private func makeAudio(at url: URL, frames: UInt32) throws {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        buffer.floatChannelData![0].initialize(repeating: 0, count: Int(frames))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
