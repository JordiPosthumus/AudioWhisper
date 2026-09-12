import XCTest
@testable import AudioWhisper

@MainActor
final class LocalSetupTests: XCTestCase {
    func testExistingInstallationDoesNotTouchRuntimeOrDownload() async {
        let setup = LocalSetupManager(supported: true, existingInstallation: { true },
            runtime: { XCTFail("Existing runtime must remain untouched") },
            download: { XCTFail("Existing model must remain untouched") },
            verify: { XCTFail("Do not add model loading to ordinary startup") })
        await setup.prepare()
        XCTAssertTrue(setup.isReady)
    }

    func testNewInstallationPreparesInOrderAndVerifiesBeforeReady() async {
        var steps: [String] = []
        let setup = LocalSetupManager(supported: true, existingInstallation: { false },
            runtime: { steps.append("runtime") }, download: { steps.append("model") },
            verify: { steps.append("offline check") })
        XCTAssertEqual(setup.state, .waiting)
        await setup.prepare()
        XCTAssertEqual(steps, ["runtime", "model", "offline check"])
        XCTAssertTrue(setup.isReady)
    }

    func testDownloadFailureCanBeRetriedAndNeverClaimsReady() async {
        var downloads = 0, verifications = 0
        let setup = LocalSetupManager(supported: true, existingInstallation: { false }, runtime: {},
            download: {
                downloads += 1
                if downloads == 1 { throw URLError(.notConnectedToInternet) }
            }, verify: { verifications += 1 })
        await setup.prepare()
        guard case .failed = setup.state else { return XCTFail("Failure must be visible") }
        XCTAssertEqual(verifications, 0)
        await setup.prepare()
        XCTAssertEqual(downloads, 2)
        XCTAssertEqual(verifications, 1)
        XCTAssertTrue(setup.isReady)
    }

    func testRepeatedClickDoesNotStartAnotherDownload() async {
        var runtimeCalls = 0
        let setup = LocalSetupManager(supported: true, existingInstallation: { false },
            runtime: { runtimeCalls += 1; try await Task.sleep(for: .milliseconds(40)) },
            download: {}, verify: {})
        let task = Task { await setup.prepare() }
        while !setup.isPreparing { await Task.yield() }
        await setup.prepare()
        await task.value
        XCTAssertEqual(runtimeCalls, 1)
        XCTAssertTrue(setup.isReady)
    }

    func testUnsupportedMacDoesNotDownloadUnusableRuntime() async {
        let setup = LocalSetupManager(supported: false, existingInstallation: { false },
            runtime: { XCTFail("Unsupported architecture") }, download: {}, verify: {})
        await setup.prepare()
        XCTAssertEqual(setup.state, .unsupported)
    }

    func testIncompleteModelCacheDoesNotSkipSetup() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = root.appendingPathComponent("models--mlx-community--parakeet-tdt-0.6b-v2")
        let snapshot = model.appendingPathComponent("snapshots/example")
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: model.appendingPathComponent("refs"), withIntermediateDirectories: true)
        try Data("example".utf8).write(to: model.appendingPathComponent("refs/main"))
        let service = ParakeetService(cacheRoot: root)
        XCTAssertFalse(service.isModelCached())
        try Data("{}".utf8).write(to: snapshot.appendingPathComponent("config.json"))
        try FileManager.default.createSymbolicLink(at: snapshot.appendingPathComponent("model.safetensors"), withDestinationURL: root.appendingPathComponent("missing"))
        XCTAssertFalse(service.isModelCached())
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("missing"))
        XCTAssertTrue(service.isModelCached())
    }
}
