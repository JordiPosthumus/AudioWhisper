import XCTest
import AppKit
@testable import AudioWhisper

final class PressAndHoldKeyMonitorTests: XCTestCase {
    private var addedEvents: [(NSEvent.EventTypeMask, (NSEvent) -> Void)] = []
    private var removedEvents: [Any] = []
    private var localEvents: [(NSEvent) -> NSEvent?] = []

    override func tearDown() {
        addedEvents.removeAll()
        removedEvents.removeAll()
        localEvents.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeMonitor(
        configuration: PressAndHoldConfiguration,
        keyDownHandler: @escaping () -> Void = {},
        keyUpHandler: (() -> Void)? = nil
    ) -> PressAndHoldKeyMonitor {
        let addMonitor: PressAndHoldKeyMonitor.EventMonitorFactory = { [weak self] mask, handler in
            self?.addedEvents.append((mask, handler))
            return self?.addedEvents.count ?? 0
        }

        let removeMonitor: PressAndHoldKeyMonitor.EventMonitorRemoval = { [weak self] token in
            self?.removedEvents.append(token)
        }

        return PressAndHoldKeyMonitor(
            configuration: configuration,
            keyDownHandler: keyDownHandler,
            keyUpHandler: keyUpHandler,
            addGlobalMonitor: addMonitor,
            addLocalMonitor: { [weak self] _, handler in
                self?.localEvents.append(handler)
                return "local"
            },
            removeMonitor: removeMonitor
        )
    }

    // MARK: - start()

    func testStartRegistersFlagMonitorForModifierKey() {
        let config = PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        let monitor = makeMonitor(configuration: config)

        monitor.start()

        XCTAssertEqual(addedEvents.count, 1)
        XCTAssertEqual(addedEvents.first?.0, .flagsChanged)
        XCTAssertEqual(localEvents.count, 1)
    }

    // MARK: - Transitions

    func testKeyDownInvokesHandlerOnlyOnceUntilReleased() {
        let expectationDown = expectation(description: "keyDown")
        expectationDown.expectedFulfillmentCount = 2

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {
                expectationDown.fulfill()
            }
        )

        monitor.processTransition(isKeyDownEvent: true)  // first press
        monitor.processTransition(isKeyDownEvent: true)  // repeat press ignored
        monitor.processTransition(isKeyDownEvent: false) // release
        monitor.processTransition(isKeyDownEvent: true)  // second press

        wait(for: [expectationDown], timeout: 1.0)
    }

    func testKeyUpInvokesHandlerWhenConfigured() {
        let expectationUp = expectation(description: "keyUp")

        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: {
                expectationUp.fulfill()
            }
        )

        monitor.processTransition(isKeyDownEvent: true)
        monitor.processTransition(isKeyDownEvent: false)

        wait(for: [expectationUp], timeout: 1.0)
    }

    func testKeyUpHandlerNotCalledWhenNeverPressed() {
        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold),
            keyDownHandler: {},
            keyUpHandler: {
                XCTFail("Key up should not fire without prior key down")
            }
        )

        monitor.processTransition(isKeyDownEvent: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    // MARK: - stop()

    func testStopRemovesRegisteredMonitors() {
        let monitor = makeMonitor(
            configuration: PressAndHoldConfiguration(enabled: true, key: .rightCommand, mode: .hold)
        )

        monitor.start()
        monitor.stop()

        XCTAssertEqual(removedEvents.count, 2)
    }

    func testPressInOtherAppAndReleaseInScribeKittPreservesEvent() throws {
        let down = expectation(description: "global press")
        let up = expectation(description: "local release")
        let monitor = makeMonitor(configuration: .defaults,
                                  keyDownHandler: { down.fulfill() }, keyUpHandler: { up.fulfill() })
        monitor.start()
        let press = try XCTUnwrap(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: .command,
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 54))
        let release = try XCTUnwrap(NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: [],
            timestamp: 1, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 54))
        addedEvents[0].1(press)
        XCTAssertTrue(localEvents[0](release) === release)
        wait(for: [down, up], timeout: 1)
    }

    func testModifierStateUsesFlagsAndDistinguishesLeftAndRight() {
        XCTAssertTrue(PressAndHoldKeyMonitor.isModifierPressed(.rightCommand, flags: .command))
        XCTAssertFalse(PressAndHoldKeyMonitor.isModifierPressed(.rightCommand, flags: []))
        let leftOnly = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | 0x08)
        XCTAssertFalse(PressAndHoldKeyMonitor.isModifierPressed(.rightCommand, flags: leftOnly))
        XCTAssertTrue(PressAndHoldKeyMonitor.isModifierPressed(.leftCommand, flags: leftOnly))
        let both = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | 0x18)
        XCTAssertTrue(PressAndHoldKeyMonitor.isModifierPressed(.rightCommand, flags: both))
    }
}
