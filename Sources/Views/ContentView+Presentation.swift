import SwiftUI
import AppKit

@MainActor
internal extension ContentView {
    func dismissRecorder() {
        completionTask?.cancel()
        completionTask = nil
        finalText = nil
        transcriptPasteboardChangeCount = nil
        transcriptWasPasted = false
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
        hideRecordingWindow()
    }

    func updateRecordingWindowSize() {
        guard let window = NSApp.windows.first(where: { $0.title == AppBrand.recordingWindowTitle }) else { return }
        let display = window.screen ?? WindowController.recordingScreen()
        let available = display?.visibleFrame.size ?? TranscriptPresentation.defaultAvailableSize
        transcriptAvailableSize = available
        let size = TranscriptPresentation.size(finalText: finalText, live: streamingPreview.isEnabledForSession,
            liveText: streamingPreview.stableText + streamingPreview.draftText, available: available)
        let screen = display?.frame ?? window.frame
        let frame = RecorderWindowGeometry.centered(size: size, on: screen)
        if window.frame != frame { window.setFrame(frame, display: true) }
    }

    func dismissCompletedTranscriptAfterPaste(changeCount: Int) {
        guard !audioRecorder.isRecording, transcriptPasteboardChangeCount != nil,
              transcriptPasteboardChangeCount == changeCount,
              transcriptPasteboardChangeCount == NSPasteboard.general.changeCount else { return }
        transcriptWasPasted = true
        completionTask?.cancel()
        completionTask = nil
        hideRecordingWindow()
        showSuccess = false
        finalText = nil
        transcriptPasteboardChangeCount = nil
    }

    func hideRecordingWindow() {
        guard let window = NSApp.windows.first(where: { $0.title == AppBrand.recordingWindowTitle }) else { return }
        let ownedFocus = window.isKeyWindow
        window.orderOut(nil)
        if ownedFocus {
            NotificationCenter.default.post(name: .restoreFocusToPreviousApp, object: nil)
        }
    }

}

internal enum RecorderWindowGeometry {
    static func centered(size: CGSize, on screen: CGRect) -> CGRect {
        CGRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
               width: size.width, height: size.height)
    }

    static func resized(_ frame: CGRect, to size: CGSize, inside visible: CGRect) -> CGRect {
        let x = max(visible.minX, min(frame.midX - size.width / 2, visible.maxX - size.width))
        let y = max(visible.minY, min(frame.minY, visible.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}
