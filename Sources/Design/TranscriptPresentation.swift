import AppKit

internal enum TranscriptPresentation {
    static let width: CGFloat = 380
    static let compactHeight: CGFloat = 112
    static let liveHeight: CGFloat = 180

    /// Short phrases flash briefly; longer text gets time to scan without a persistent panel.
    static func duration(for text: String) -> TimeInterval {
        let words = text.split(whereSeparator: { $0.isWhitespace }).count
        return min(6, max(0.85, 0.65 + Double(words) * 0.045))
    }

    static func size(finalText: String?, live: Bool) -> CGSize {
        guard let finalText else { return CGSize(width: width, height: live ? liveHeight : compactHeight) }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        let bounds = (finalText as NSString).boundingRect(
            with: CGSize(width: width - 40, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 15), .paragraphStyle: paragraph]
        )
        return CGSize(width: width, height: min(340, max(150, ceil(bounds.height) + 110)))
    }

    static func liveTail(stable: String, draft: String, limit: Int = 130) -> (stable: String, draft: String) {
        let draftTail = String(draft.suffix(limit))
        return (String(stable.suffix(max(0, limit - draftTail.count))), draftTail)
    }
}
