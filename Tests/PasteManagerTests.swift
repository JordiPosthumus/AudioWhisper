import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class PasteManagerTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        suiteName = "PasteManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        pasteboard = NSPasteboard.withUniqueName()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        pasteboard.releaseGlobally()
        defaults.removeObject(forKey: "enableSmartPaste")
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeManager(permissionGranted: Bool) -> PasteManager {
        let manager = PasteManager(
            accessibilityManager: AccessibilityPermissionManager(permissionCheck: { permissionGranted }),
            defaults: defaults, pasteboard: pasteboard
        )
        return manager
    }

    // MARK: - Tests

    func testSmartPasteDisabledPostsFailureAndSkipsActivation() async throws {
        defaults.set(false, forKey: "enableSmartPaste")

        let mockApp = MockRunningApplication()
        let manager = makeManager(permissionGranted: true)

        // Set up notification expectation before calling smartPaste
        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: mockApp, text: "hello world")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
        XCTAssertEqual(mockApp.mockActivationCount, 0)
        XCTAssertEqual(pasteboard.string(forType: .string), "hello world")
    }

    func testSmartPasteFailsWhenPermissionDenied() async throws {
        defaults.set(true, forKey: "enableSmartPaste")

        let mockApp = MockRunningApplication()
        let manager = makeManager(permissionGranted: false)

        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: mockApp, text: "needs permission")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
        XCTAssertEqual(mockApp.mockActivationCount, 0)
    }

    func testSmartPasteFailsForNilTargetApplication() async throws {
        defaults.set(true, forKey: "enableSmartPaste")

        let manager = makeManager(permissionGranted: true)

        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: nil, text: "no target app")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
    }

    func testSmartPasteAttemptsActivationThenFailsInsideTests() async throws {
        defaults.set(true, forKey: "enableSmartPaste")

        let mockApp = MockRunningApplication()
        let manager = makeManager(permissionGranted: true)

        let notificationReceived = expectation(description: "PasteOperationFailed fired")
        let observer = NotificationCenter.default.addObserver(
            forName: .pasteOperationFailed,
            object: nil,
            queue: nil
        ) { _ in
            notificationReceived.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.smartPaste(into: mockApp, text: "attempt paste")

        await fulfillment(of: [notificationReceived], timeout: 1.0)
        XCTAssertEqual(mockApp.mockActivationCount, 1)
    }
}
