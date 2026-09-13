import XCTest
import AppKit
@testable import AudioWhisper

@MainActor
final class TranscriptClipboardTests: XCTestCase {
    private func preferences() -> UserDefaults {
        let name = "ScribeKitt.ClipboardTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testCompletedTranscriptReplacesPreviousClipboardExactlyWhenDisabled() {
        let defaults = preferences()
        defaults.set(false, forKey: AppDefaults.Keys.addTrailingSpace)
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.setString("Previous clipboard", forType: .string)
        let text = "Manual paste: café 🎙️\nSecond line."
        XCTAssertTrue(TranscriptClipboard.copy(text, to: board, defaults: defaults))
        XCTAssertEqual(board.string(forType: .string), text)
        XCTAssertTrue(TranscriptClipboard.copy("Next dictation", to: board, defaults: defaults))
        XCTAssertEqual(board.string(forType: .string), "Next dictation")
    }

    func testConsecutiveSentencesPasteWithSpaceByDefault() {
        let defaults = preferences()
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        XCTAssertTrue(TranscriptClipboard.copy("First sentence.", to: board, defaults: defaults))
        let firstPaste = board.string(forType: .string)!
        XCTAssertTrue(TranscriptClipboard.copy("Second sentence.", to: board, defaults: defaults))
        XCTAssertEqual(firstPaste + board.string(forType: .string)!, "First sentence. Second sentence. ")
    }

    func testToggleAppliesToNextCopy() {
        let defaults = preferences()
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        for enabled in [false, true, false] {
            defaults.set(enabled, forKey: AppDefaults.Keys.addTrailingSpace)
            TranscriptClipboard.copy("Hello.", to: board, defaults: defaults)
            XCTAssertEqual(board.string(forType: .string), enabled ? "Hello. " : "Hello.")
        }
    }

    func testPunctuationQuotesAndExistingWhitespace() {
        for text in ["Hello.", "Really?", "Yes!", "She said “Hello.”", "(Finished.)", "First.\nSecond.", "Wait… Done."] {
            XCTAssertEqual(TranscriptClipboard.textForCopy(text, addTrailingSpace: true), text + " ")
        }
        for text in ["", " ", "Hello. ", "Hello.\n", "Hello.\t", "Hello.\u{00A0}", "No punctuation", "3.14", "https://example.com"] {
            XCTAssertEqual(TranscriptClipboard.textForCopy(text, addTrailingSpace: true), text)
        }
    }
}
