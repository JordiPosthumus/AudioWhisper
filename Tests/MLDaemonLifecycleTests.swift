import XCTest
@testable import AudioWhisper

final class MLDaemonLifecycleTests: XCTestCase {
    func testWarmupFailureIsNotReportedAsReady() async {
        let manager = MLDaemonManager()
        await manager.setTestResponder { _, _ in ["success": false, "error": "missing weights"] }
        do {
            try await manager.warmup(type: "parakeet", repo: "test")
            XCTFail("False success must fail warmup")
        } catch {
            guard case MLDaemonError.remoteError(let message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(message, "missing weights")
        }
    }

    func testScalarResponseReturnsDecodingErrorInsteadOfCrashing() async {
        let manager = MLDaemonManager()
        await manager.setTestResponder { _, _ in false }
        do {
            try await manager.warmup(type: "parakeet", repo: "test")
            XCTFail("Expected invalid response")
        } catch {
            guard case MLDaemonError.invalidResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testCancelledRequestReleasesCallerAndKeepsDaemonAlive() async throws {
        let (manager, script) = try await makeManager()
        let request = Task { try await manager.correct(repo: "test", text: "hello", prompt: nil) }
        let pending = await waitUntil { await manager.pendingRequestCountForTesting == 1 }
        XCTAssertTrue(pending)
        let pid = await manager.processIdentifierForTesting
        request.cancel()
        do {
            _ = try await request.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        let remaining = await manager.pendingRequestCountForTesting
        XCTAssertEqual(remaining, 0)
        let pong = await manager.ping()
        XCTAssertTrue(pong)
        let afterPID = await manager.processIdentifierForTesting
        XCTAssertEqual(pid, afterPID, "Cancellation must not restart the model daemon")
        await manager.shutdown()
        try FileManager.default.removeItem(at: script)
    }

    func testCancellationRemainsResponsiveWhenDaemonStdinIsFull() async throws {
        let (manager, script) = try await makeManager()
        let release = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let blocked = Task { try await manager.correct(repo: "blocked", text: release.path, prompt: nil) }
        let pending = await waitUntil { await manager.pendingRequestCountForTesting == 1 }
        XCTAssertTrue(pending)
        // Always release the fake daemon, including when a regression blocks its stdin writer.
        let unblock = Task {
            try? await Task.sleep(for: .seconds(1))
            FileManager.default.createFile(atPath: release.path, contents: Data())
        }
        let request = Task { try await manager.correct(repo: "test", text: String(repeating: "x", count: 1_000_000), prompt: nil) }
        try await Task.sleep(for: .milliseconds(50))
        let cancelled = expectation(description: "Cancellation does not wait for the blocked pipe")
        request.cancel()
        let check = Task {
            do {
                _ = try await request.value
                XCTFail("Expected cancellation")
            } catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
            cancelled.fulfill()
        }
        await fulfillment(of: [cancelled], timeout: 0.5)
        await unblock.value
        _ = try await blocked.value
        await check.value
        await manager.shutdown()
        try? FileManager.default.removeItem(at: release)
        try? FileManager.default.removeItem(at: script)
    }

    func testChildCrashFailsPendingRequestAndRestarts() async throws {
        let (manager, script) = try await makeManager()
        do {
            try await manager.warmup(type: "parakeet", repo: "crash")
            XCTFail("Expected daemon exit to fail request")
        } catch {
            guard case MLDaemonError.daemonUnavailable = error else {
                await manager.shutdown()
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let pong = await manager.ping()
        XCTAssertTrue(pong, "Subsequent requests must reach the replacement daemon")
        await manager.shutdown()
        try FileManager.default.removeItem(at: script)
    }

    private func makeManager() async throws -> (MLDaemonManager, URL) {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("daemon-test-\(UUID().uuidString).py")
        try """
        import sys, json, time, os
        for line in sys.stdin:
            r = json.loads(line)
            if r.get('params', {}).get('repo') == 'crash':
                os._exit(7)
            if r.get('params', {}).get('repo') == 'blocked':
                while not os.path.exists(r['params']['text']):
                    time.sleep(0.01)
            if r['method'] == 'correct':
                time.sleep(0.15)
                result = {'success': True, 'text': 'hello'}
            else:
                result = {'pong': True}
            print(json.dumps({'jsonrpc': '2.0', 'id': r['id'], 'result': result}), flush=True)
        """.write(to: script, atomically: true, encoding: .utf8)
        let manager = MLDaemonManager()
        await manager.setTestOverrides(python: URL(fileURLWithPath: "/usr/bin/python3"), script: script)
        return (manager, script)
    }

    private func waitUntil(_ predicate: () async -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if await predicate() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }
}
