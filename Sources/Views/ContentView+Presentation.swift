import SwiftUI
import AppKit

@MainActor
internal extension ContentView {
    func copyPreview() {
        guard showSuccess, !previewText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(previewText, forType: .string)
        pasteMessage = "Copied to clipboard"
    }

    func dismissRecorder() {
        pasteTask?.cancel()
        pasteTask = nil
        isPasting = false
        processingTask?.cancel()
        processingTask = nil
        activeTranscriptionID = nil
        if audioRecorder.isRecording {
            audioRecorder.cancelRecording()
            NotificationCenter.default.post(name: .recordingStopped, object: nil)
        }
        isProcessing = false
        transcriptionStartTime = nil
        showSuccess = false
        pasteMessage = nil
        hideRecordingWindow()
        NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
    }

    func updateRecordingWindowSize() {
        guard let window = NSApp.windows.first(where: { $0.title == AppBrand.recordingWindowTitle }) else { return }
        let size = showSuccess ? RecorderWindowGeometry.previewSize(text: previewText, message: pasteMessage) : LayoutMetrics.RecordingWindow.size
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? window.frame
        let frame = RecorderWindowGeometry.resized(window.frame, to: size, inside: visible)
        window.setFrame(frame, display: true)
    }

    func showPreviewWindow() {
        guard let window = NSApp.windows.first(where: { $0.title == AppBrand.recordingWindowTitle }) else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)
    }
}

internal enum RecorderWindowGeometry {
    static func previewSize(text: String, message: String?) -> CGSize {
        let width = LayoutMetrics.RecordingWindow.previewSize.width
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        paragraph.lineBreakMode = .byWordWrapping
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width - 32, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 15), .paragraphStyle: paragraph]
        )
        let textHeight = min(156, max(36, ceil(bounds.height)))
        return CGSize(width: width, height: max(180, textHeight + 140 + (message == nil ? 0 : 32)))
    }

    static func resized(_ frame: CGRect, to size: CGSize, inside visible: CGRect) -> CGRect {
        let x = max(visible.minX, min(frame.midX - size.width / 2, visible.maxX - size.width))
        let y = max(visible.minY, min(frame.minY, visible.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
