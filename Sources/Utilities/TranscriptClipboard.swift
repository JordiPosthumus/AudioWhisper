import AppKit

@MainActor
internal enum TranscriptClipboard {
    @discardableResult
    static func copy(_ text: String, to pasteboard: NSPasteboard = .general,
                     defaults: UserDefaults = .standard) -> Bool {
        let enabled = defaults.object(forKey: AppDefaults.Keys.addTrailingSpace) as? Bool ?? true
        pasteboard.clearContents()
        return pasteboard.setString(textForCopy(text, addTrailingSpace: enabled), forType: .string)
    }

    static func textForCopy(_ text: String, addTrailingSpace: Bool) -> String {
        guard addTrailingSpace, let last = text.last, !last.isWhitespace else { return text }
        // Only format the clipboard boundary; don't rewrite sentence interiors,
        // decimal points, URLs, or the transcript stored in history.
        let closingMarks: Set<Character> = ["\"", "'", "”", "’", "»", ")", "]", "}"]
        let ending = text.reversed().drop(while: { closingMarks.contains($0) }).first
        guard let ending, ".!?".contains(ending) else { return text }
        return text + " "
    }
}
