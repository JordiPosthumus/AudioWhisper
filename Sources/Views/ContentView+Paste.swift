import SwiftUI
import AppKit

@MainActor
internal extension ContentView {
    func performUserTriggeredPaste() {
        guard showSuccess, !previewText.isEmpty, !isPasting else { return }
        let requestID = activeTranscriptionID
        let text = previewText
        let target = findValidTargetApp()
        isPasting = true
        pasteMessage = nil
        pasteTask = Task { @MainActor in
            do {
                try await pasteManager.pasteReviewedText(text, into: target)
                try Task.checkCancellation()
                guard activeTranscriptionID == requestID else { return }
                isPasting = false
                showSuccess = false
                hideRecordingWindow()
            } catch is CancellationError {
                // Dismiss/new recording already owns the current UI state.
            } catch {
                guard activeTranscriptionID == requestID else { return }
                isPasting = false
                pasteMessage = "Couldn’t paste. Your text is copied—use ⌘V."
                showPreviewWindow()
            }
        }
    }

    func findValidTargetApp() -> NSRunningApplication? {
        [WindowController.storedTargetApp, targetAppForPaste]
            .compactMap { $0 }
            .first { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }

    func hideRecordingWindow() {
        NSApp.windows.first { $0.title == AppBrand.recordingWindowTitle }?.orderOut(nil)
    }
}
