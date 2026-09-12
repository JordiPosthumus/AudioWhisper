import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class ReviewedPasteTests: XCTestCase {
    private var board: NSPasteboard!
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        board = .withUniqueName()
        suite = "ReviewedPaste.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(false, forKey: "enableSmartPaste")
    }

    override func tearDown() {
        board.releaseGlobally()
        defaults.removePersistentDomain(forName: suite)
    }

    func testExplicitPasteWorksWithAutomaticPasteDisabled() async throws {
        let target = MockRunningApplication()
        target.mockIsActive = true
        var events = 0
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { true }), defaults: defaults, pasteboard: board, eventPoster: { events += 1 })
        try await manager.pasteReviewedText("Reviewed text", into: target)
        XCTAssertEqual(target.mockActivationCount, 1)
        XCTAssertEqual(events, 1)
        XCTAssertEqual(board.string(forType: .string), "Reviewed text")
        XCTAssertFalse(defaults.bool(forKey: "enableSmartPaste"), "Explicit Paste must not change the stored preference")
    }

    func testReviewedTextIsRestoredAfterClipboardChangesDuringActivation() async throws {
        let target = MockRunningApplication()
        target.mockIsActive = true
        target.activationHandler = { [self] in
            board.clearContents()
            board.setString("Unrelated clipboard content", forType: .string)
            return true
        }
        var pastedText: String?
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { true }), defaults: defaults, pasteboard: board,
            eventPoster: { [self] in pastedText = board.string(forType: .string) })
        try await manager.pasteReviewedText("The reviewed transcript", into: target)
        XCTAssertEqual(pastedText, "The reviewed transcript")
    }

    func testMissingTargetCopiesTextWithoutChoosingAnotherApp() async {
        var events = 0
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { true }), defaults: defaults, pasteboard: board, eventPoster: { events += 1 })
        do {
            try await manager.pasteReviewedText("Keep this text", into: nil)
            XCTFail("Expected unavailable target")
        } catch { XCTAssertEqual(error as? PasteError, .targetAppNotAvailable) }
        XCTAssertEqual(events, 0)
        XCTAssertEqual(board.string(forType: .string), "Keep this text")
    }

    func testDeniedPermissionDoesNotActivateOrPost() async {
        let target = MockRunningApplication()
        target.mockIsActive = true
        var events = 0
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { false }), defaults: defaults, pasteboard: board, eventPoster: { events += 1 })
        do {
            try await manager.pasteReviewedText("Copy fallback", into: target)
            XCTFail("Expected permission error")
        } catch { XCTAssertEqual(error as? PasteError, .accessibilityPermissionDenied) }
        XCTAssertEqual(target.mockActivationCount, 0)
        XCTAssertEqual(events, 0)
        XCTAssertEqual(board.string(forType: .string), "Copy fallback")
    }

    func testRevokedPermissionAfterActivationPreventsPaste() async {
        var permission = true
        let target = MockRunningApplication()
        target.mockIsActive = true
        target.activationHandler = { permission = false; return true }
        var events = 0
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { permission }), defaults: defaults, pasteboard: board, eventPoster: { events += 1 })
        do {
            try await manager.pasteReviewedText("Still copied", into: target)
            XCTFail("Expected revoked permission error")
        } catch { XCTAssertEqual(error as? PasteError, .accessibilityPermissionDenied) }
        XCTAssertEqual(events, 0)
        XCTAssertEqual(board.string(forType: .string), "Still copied")
    }

    func testFailedActivationNeverPostsPaste() async {
        let target = MockRunningApplication()
        target.activationHandler = { false }
        var events = 0
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { true }), defaults: defaults, pasteboard: board, eventPoster: { events += 1 })
        do {
            try await manager.pasteReviewedText("Keep preview", into: target)
            XCTFail("Expected activation failure")
        } catch { XCTAssertEqual(error as? PasteError, .targetAppNotAvailable) }
        XCTAssertEqual(events, 0)
    }

    func testCancellationDuringActivationNeverPostsPaste() async throws {
        let target = MockRunningApplication()
        var events = 0
        let manager = PasteManager(accessibilityManager: AccessibilityPermissionManager(permissionCheck: { true }), defaults: defaults, pasteboard: board, eventPoster: { events += 1 })
        let task = Task { try await manager.pasteReviewedText("Cancelled review", into: target) }
        let deadline = ContinuousClock.now + .seconds(1)
        while target.mockActivationCount == 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(target.mockActivationCount, 1)
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(events, 0)
    }
}
