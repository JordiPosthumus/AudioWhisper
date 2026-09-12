import XCTest
@testable import AudioWhisper

final class ProcessOutputTests: XCTestCase {
    func testDrainsLargeStdoutAndStderrWithoutDeadlock() async throws {
        let done = expectation(description: "Both pipes drained")
        DispatchQueue.global().async {
            let (out, err, status) = ProcessOutput.run("/bin/sh", ["-c", "head -c 1048576 /dev/zero; head -c 1048576 /dev/zero >&2; exit 7"])
            XCTAssertEqual(status, 7)
            XCTAssertEqual(out.utf8.count, 1_048_576)
            XCTAssertEqual(err.utf8.count, 1_048_576)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 15)
    }

    func testWorkingDirectoryAndLaunchFailure() throws {
        let directory = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        let (out, err, status) = ProcessOutput.run("/bin/pwd", [], directory: directory)
        XCTAssertEqual(status, 0)
        let actual = URL(fileURLWithPath: out.trimmingCharacters(in: .whitespacesAndNewlines))
        let actualID = try XCTUnwrap(actual.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject)
        let expectedID = try XCTUnwrap(directory.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject)
        XCTAssertEqual(actualID, expectedID)
        XCTAssertEqual(err, "")
        let (_, failure, exitCode) = ProcessOutput.run("/missing/command", [])
        XCTAssertNotEqual(exitCode, 0)
        XCTAssertFalse(failure.isEmpty)
    }
}
