import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class TranscriptClipboardTests: XCTestCase {
    func testCompletedTranscriptReplacesPreviousClipboardExactly() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let text = "Manual paste: café 🎙️\nSecond line."
        XCTAssertTrue(TranscriptClipboard.copy(text, to: board))
        XCTAssertEqual(board.string(forType: .string), text)
        XCTAssertTrue(TranscriptClipboard.copy("Next dictation", to: board))
        XCTAssertEqual(board.string(forType: .string), "Next dictation")
    }
}
