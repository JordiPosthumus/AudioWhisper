import XCTest
import AppKit
@testable import AudioWhisper

final class RecorderPresentationTests: XCTestCase {
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

    func testPreviewExpansionKeepsBottomAnchorAndStaysOnScreen() {
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

    func testPreviewFitsShortTextAndBoundsLongText() {
        let short = RecorderWindowGeometry.previewSize(text: "Hello", message: nil)
        let long = RecorderWindowGeometry.previewSize(text: String(repeating: "A long transcript with many words. ", count: 500), message: nil)
        XCTAssertLessThan(short.height, long.height)
        XCTAssertLessThanOrEqual(long.height, 296)
        XCTAssertGreaterThan(RecorderWindowGeometry.previewSize(text: "Hello", message: "Copied").height, short.height)
    }

    @MainActor
    func testBorderlessRecorderCanReceiveEnterAndEscape() {
        let window = ChromelessWindow(contentRect: CGRect(x: 0, y: 0, width: 224, height: 64), styleMask: [.borderless], backing: .buffered, defer: true)
        XCTAssertTrue(window.canBecomeKey)
    }
}
