import SwiftUI
import AppKit

@MainActor
internal extension ContentView {
    func performUserTriggeredPaste() {
        guard let target = findValidTargetApp() else {
            showSuccess = false
            hideRecordingWindow()
            return
        }
        hideRecordingWindow()
        guard target.activate(options: []) else {
            showSuccess = false
            return
        }
        ApplicationActivationWaiter.wait(for: target) { activated in
            guard activated, target.isActive else {
                showSuccess = false
                return
            }
            pasteManager.pasteWithUserInteraction { _ in showSuccess = false }
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
