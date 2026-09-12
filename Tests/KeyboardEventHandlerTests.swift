import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class KeyboardEventHandlerTests: XCTestCase {
    private var handler: KeyboardEventHandler!
    private var window: NSWindow!

    override func setUp() {
        super.setUp()
        handler = KeyboardEventHandler(isTestEnvironment: true)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.title = AppBrand.recordingWindowTitle
    }

    override func tearDown() {
        window = nil
        handler = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func keyEvent(characters: String, charactersIgnoringModifiers: String? = nil, modifiers: NSEvent.ModifierFlags = [], keyCode: UInt16 = 0) -> NSEvent? {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers ?? characters,
            isARepeat: false,
            keyCode: keyCode
        )
    }

    // MARK: - Key Handling
    
    func testSpaceKeyPostsNotificationAndConsumesEvent() {
        let expectation = expectation(forNotification: .spaceKeyPressed, object: nil)
        guard let event = keyEvent(characters: " ", keyCode: 49) else {
            XCTFail("Failed to create key event")
            return
        }

        let result = handler.handleKeyEvent(event, for: window)

        XCTAssertNil(result)
        wait(for: [expectation], timeout: 1)
    }

    func testEscapeKeyPostsNotificationAndConsumesEvent() {
        let expectation = expectation(forNotification: .escapeKeyPressed, object: nil)
        let escapeCharacter = String(Character(UnicodeScalar(27)!))
        guard let event = keyEvent(characters: escapeCharacter, keyCode: 53) else {
            XCTFail("Failed to create key event")
            return
        }

        let result = handler.handleKeyEvent(event, for: window)

        XCTAssertNil(result)
        wait(for: [expectation], timeout: 1)
    }

    func testReturnKeyPassesThroughWithoutPasting() {
        guard let event = keyEvent(characters: "\r", keyCode: 36) else {
            return XCTFail("Failed to create key event")
        }
        XCTAssertTrue(handler.handleKeyEvent(event, for: window) === event)
    }

    func testCommandCommaConsumesEvent() {
        guard let event = keyEvent(characters: ",", modifiers: [.command], keyCode: 0) else {
            XCTFail("Failed to create key event")
            return
        }

        let result = handler.handleKeyEvent(event, for: window)

        XCTAssertNil(result, "Command+Comma should be consumed to open dashboard")
    }

    func testNativeCopyShortcutPassesThrough() {
        guard let event = keyEvent(characters: "c", modifiers: [.command], keyCode: 8) else {
            XCTFail("Failed to create key event")
            return
        }

        let result = handler.handleKeyEvent(event, for: window)

        XCTAssertNotNil(result, "Command+C must reach native transcript selection")
    }

    func testPasteNotifiesWithoutConsumingTheNativeShortcut() throws {
        let expectation = expectation(forNotification: .transcriptPasteShortcut, object: nil)
        let event = try XCTUnwrap(keyEvent(characters: "v", modifiers: [.command], keyCode: 9))
        XCTAssertTrue(handler.handleKeyEvent(event, for: window) === event)
        wait(for: [expectation], timeout: 1)
    }

    func testPasteAndMatchStyleIsRecognizedButOrdinaryVIsNot() throws {
        let paste = try XCTUnwrap(keyEvent(characters: "V", modifiers: [.command, .shift, .option], keyCode: 9))
        XCTAssertTrue(KeyboardEventHandler.isPasteShortcut(paste))
        let typing = try XCTUnwrap(keyEvent(characters: "v", keyCode: 9))
        XCTAssertFalse(KeyboardEventHandler.isPasteShortcut(typing))
        let control = try XCTUnwrap(keyEvent(characters: "v", modifiers: [.command, .control], keyCode: 9))
        XCTAssertFalse(KeyboardEventHandler.isPasteShortcut(control))
    }

    func testNonCommandKeysPassThrough() {
        guard let event = keyEvent(characters: "a", keyCode: 0) else {
            XCTFail("Failed to create key event")
            return
        }

        let result = handler.handleKeyEvent(event, for: window)

        XCTAssertNotNil(result, "Non-command keys should pass through")
    }
}
