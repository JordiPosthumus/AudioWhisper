import XCTest
import Combine
@testable import AudioWhisper

/// Opt-in: downloads into a new temporary runtime/cache, never the owner's installation.
@MainActor
final class LocalSetupIntegrationTests: XCTestCase {
    func testFreshRuntimeModelDownloadAndOfflineTranscription() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let path = env["SCRIBEKITT_FRESH_TEST_ROOT"],
              let audio = env["SPEEDYWHISPER_MODEL_TEST_AUDIO"] else {
            throw XCTSkip("Set SCRIBEKITT_FRESH_TEST_ROOT for the isolated first-run download check")
        }
        let root = URL(fileURLWithPath: path).standardizedFileURL
        guard root.path.hasPrefix("/tmp/scribekitt-fresh-") || root.path.hasPrefix("/private/tmp/scribekitt-fresh-") else {
            return XCTFail("Fresh setup must use a dedicated temporary directory")
        }
        XCTAssertEqual(env["AUDIOWHISPER_APP_SUPPORT_DIR"], root.appendingPathComponent("support").path)
        XCTAssertEqual(env["HF_HUB_CACHE"], root.appendingPathComponent("hf").path)
        let project = root.appendingPathComponent("support/AudioWhisper/python_project")
        XCTAssertFalse(FileManager.default.fileExists(atPath: project.appendingPathComponent(".venv").path))
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        // XCTest's executable bundle has no runtime manifest. Seed the exact file
        // copied from the app bundle by UvBootstrap in an ordinary installation.
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source.appendingPathComponent("Sources/Resources/pyproject.toml"),
                                        to: project.appendingPathComponent("pyproject.toml"))
        let model = ParakeetService(cacheRoot: root.appendingPathComponent("hf"))
        XCTAssertFalse(model.isModelCached())
        let daemon = MLDaemonManager()
        await daemon.setTestOverrides(python: nil, script: source.appendingPathComponent("Sources/ml_daemon.py"))
        let start = Date()
        let setup = LocalSetupManager(supported: true, existingInstallation: { false },
            runtime: { try await daemon.prepareRuntime() },
            download: { try await daemon.prepareModel() },
            verify: { try await daemon.verifySetup() })
        let observation = setup.$state.sink { print("Fresh setup at \(Date().timeIntervalSince(start))s: \($0)") }
        await setup.prepare()
        XCTAssertTrue(setup.isReady, "\(setup.state)")
        guard setup.isReady else { await daemon.shutdown(); return }
        XCTAssertTrue(model.isModelCached())
        do {
            let before = Date()
            let transcript = try await daemon.transcribe(repo: ParakeetModel.v2English.rawValue, pcmPath: audio)
            XCTAssertFalse(transcript.isEmpty)
            print("Fresh installation final inference: \(Date().timeIntervalSince(before))s")
            // Cache reuse must be sufficient when setup is requested again.
            try await daemon.prepareModel()
            let second = try await daemon.transcribe(repo: ParakeetModel.v2English.rawValue, pcmPath: audio)
            XCTAssertEqual(second, transcript)
            try JSONSerialization.data(withJSONObject: ["setup_seconds": Date().timeIntervalSince(start), "transcript": transcript])
                .write(to: root.appendingPathComponent("result.json"))
            await daemon.shutdown()
        } catch {
            await daemon.shutdown()
            throw error
        }
        withExtendedLifetime(observation) {}
    }
}
