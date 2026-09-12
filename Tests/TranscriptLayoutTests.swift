import XCTest
import AppKit
@testable import AudioWhisper

final class TranscriptLayoutTests: XCTestCase {
    func testNormalLongTranscriptIsFullyVisibleWithoutScrolling() {
        let text = String(repeating: "This is a complete sentence with several clearly readable words. ", count: 22).trimmingCharacters(in: .whitespaces)
        let layout = TranscriptPresentation.layout(text: text, live: false)
        XCTAssertEqual(layout.text, text)
        XCTAssertFalse(layout.isTruncated)
        XCTAssertGreaterThan(layout.size.height, TranscriptPresentation.compactHeight)
        XCTAssertLessThanOrEqual(TranscriptPresentation.textHeight(layout.text, width: layout.textWidth), layout.bodyHeight)
    }

    func testVeryLongTextRespectsScreenBoundsAndLabelsExcerpt() {
        let text = String(repeating: "A longer dictation fills the available display area. ", count: 150)
        let layout = TranscriptPresentation.layout(text: text, live: false, available: CGSize(width: 800, height: 600))
        XCTAssertTrue(layout.isTruncated)
        XCTAssertLessThanOrEqual(layout.size.width, 752)
        XCTAssertLessThanOrEqual(layout.size.height, 520)
        XCTAssertTrue(layout.text.hasPrefix("A longer dictation"))
        XCTAssertTrue(layout.text.hasSuffix("…"))
        XCTAssertLessThanOrEqual(TranscriptPresentation.textHeight(layout.text, width: layout.textWidth), layout.bodyHeight - 24)
    }

    func testLiveExcerptKeepsTheNewestWordsAtTheScreenLimit() {
        let text = String(repeating: "Earlier words remain part of the transcript. ", count: 150) + "These are the newest words."
        let layout = TranscriptPresentation.layout(text: text, live: true, available: CGSize(width: 800, height: 600))
        XCTAssertTrue(layout.isTruncated)
        XCTAssertTrue(layout.text.hasSuffix("These are the newest words."))
        XCTAssertTrue(layout.text.hasPrefix("…"))
    }
}
