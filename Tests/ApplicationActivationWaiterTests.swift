import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class ApplicationActivationWaiterTests: XCTestCase {
    func testAlreadyActiveCompletesImmediately() {
        let app = MockRunningApplication()
        app.mockIsActive = true
        var activated = false
        ApplicationActivationWaiter.wait(for: app, center: NotificationCenter()) { activated = $0 }
        XCTAssertTrue(activated)
    }

    func testMatchingNotificationCompletesOnceBeforeTimeout() async {
        let center = NotificationCenter()
        let app = MockRunningApplication()
        let other = MockRunningApplication()
        other.mockProcessIdentifier = 456
        var results: [Bool] = []
        ApplicationActivationWaiter.wait(for: app, center: center, timeout: 0.02) { results.append($0) }
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil,
                    userInfo: [NSWorkspace.applicationUserInfoKey: other])
        XCTAssertTrue(results.isEmpty)
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil,
                    userInfo: [NSWorkspace.applicationUserInfoKey: app])
        XCTAssertEqual(results, [true])
        try? await Task.sleep(for: .milliseconds(50))
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil,
                    userInfo: [NSWorkspace.applicationUserInfoKey: app])
        XCTAssertEqual(results, [true], "Observer and timeout must be removed after success")
    }

    func testTimeoutDoesNotPasteIntoInactiveTargetAndCompletesOnce() async {
        let center = NotificationCenter()
        let app = MockRunningApplication()
        let completed = expectation(description: "Activation timed out")
        var results: [Bool] = []
        ApplicationActivationWaiter.wait(for: app, center: center, timeout: 0.01) {
            results.append($0)
            completed.fulfill()
        }
        await fulfillment(of: [completed], timeout: 1)
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: nil,
                    userInfo: [NSWorkspace.applicationUserInfoKey: app])
        XCTAssertEqual(results, [false])
    }
}
