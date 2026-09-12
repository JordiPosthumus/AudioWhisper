import XCTest
import AppKit
@testable import AudioWhisper

final class RecorderPresentationTests: XCTestCase {
    func testRecorderIsExactlyCenteredOnEachDisplay() {
        let size = CGSize(width: 224, height: 64)
        for screen in [CGRect(x: 0, y: 0, width: 1728, height: 1117),
                       CGRect(x: -1920, y: -300, width: 1920, height: 1080),
                       CGRect(x: 1728, y: 100, width: 2560, height: 1440)] {
            let frame = RecorderWindowGeometry.centered(size: size, on: screen)
            XCTAssertEqual(frame.midX, screen.midX)
            XCTAssertEqual(frame.midY, screen.midY)
            XCTAssertEqual(frame.size, size)
        }
    }

    func testMeterRejectsNonFiniteValuesAndClampsBounds() {
        XCTAssertEqual(AudioLevelDisplay.clamped(.nan), 0)
        XCTAssertEqual(AudioLevelDisplay.clamped(.infinity), 0)
        XCTAssertEqual(AudioLevelDisplay.clamped(-1), 0)
        XCTAssertEqual(AudioLevelDisplay.clamped(2), 1)
        XCTAssertEqual(AudioLevelDisplay.clamped(0.5), 0.5)
    }

    func testSilenceDoesNotProduceFakeMeterActivity() {
        XCTAssertEqual((0..<12).filter { AudioLevelDisplay.isLit(index: $0, count: 12, level: 0) }.count, 0)
        XCTAssertEqual((0..<12).filter { AudioLevelDisplay.isLit(index: $0, count: 12, level: 0.5) }.count, 6)
        XCTAssertEqual((0..<12).filter { AudioLevelDisplay.isLit(index: $0, count: 12, level: 1) }.count, 12)
    }

    func testRecorderResizingKeepsBottomAnchorAndStaysOnScreen() {
        let screen = CGRect(x: 1440, y: -200, width: 1440, height: 900)
        let bar = CGRect(x: 2700, y: 660, width: 224, height: 64)
        let preview = RecorderWindowGeometry.resized(bar, to: CGSize(width: 380, height: 272), inside: screen)
        XCTAssertTrue(screen.contains(preview))
        XCTAssertEqual(preview.maxX, screen.maxX)
        XCTAssertEqual(preview.maxY, screen.maxY)
        let lowBar = CGRect(x: 1700, y: -164, width: 224, height: 64)
        let lowPreview = RecorderWindowGeometry.resized(lowBar, to: CGSize(width: 380, height: 272), inside: screen)
        XCTAssertEqual(lowPreview.minY, lowBar.minY)
        XCTAssertEqual(lowPreview.midX, lowBar.midX)
    }

    @MainActor
    func testBorderlessRecorderCanReceiveEscape() {
        let window = ChromelessWindow(contentRect: CGRect(x: 0, y: 0, width: 224, height: 64), styleMask: [.borderless], backing: .buffered, defer: true)
        XCTAssertTrue(window.canBecomeKey)
    }
}
