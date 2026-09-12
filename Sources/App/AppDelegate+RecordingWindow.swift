import AppKit
import os.log
import SwiftData
import SwiftUI

internal extension AppDelegate {
    @objc func toggleRecordWindow() {
        if recordingWindow == nil {
            createRecordingWindow()
        }
        windowController.toggleRecordWindow(recordingWindow)
    }

    func showRecordingIndicator() {
        if recordingWindow == nil { createRecordingWindow() }
        guard let window = recordingWindow else { return }
        windowController.showRecordingIndicator(window)
    }

    func showRecordingWindowForProcessing(completion: (() -> Void)? = nil) {
        if recordingWindow == nil {
            createRecordingWindow()
        }

        guard let window = recordingWindow else {
            completion?()
            return
        }

        if window.isVisible {
            completion?()
        } else {
            windowController.toggleRecordWindow(window) {
                completion?()
            }
        }
    }

    func createRecordingWindow() {
        guard let recorder = audioRecorder else {
            Logger.app.error("Cannot create recording window: AudioRecorder not initialized")
            return
        }

        let windowSize = LayoutMetrics.RecordingWindow.size
        let window = ChromelessWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.title = AppBrand.recordingWindowTitle
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isOpaque = false

        let contentView = ContentView(audioRecorder: recorder)
            .modelContainer(DataManager.shared.sharedModelContainer ?? createFallbackModelContainer())

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.sizingOptions = []
        window.contentView = hostingView
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: visible.midX - windowSize.width / 2, y: visible.minY + 36))
        }
        window.isReleasedWhenClosed = false

        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        recordingWindowDelegate = RecordingWindowDelegate { [weak self] in
            self?.onRecordingWindowClosed()
        }
        window.delegate = recordingWindowDelegate

        recordingWindow = window
    }

    private func onRecordingWindowClosed() {
        recordingWindow = nil
        recordingWindowDelegate = nil
        Logger.app.info("Recording window closed and references cleaned up")
    }

    private func createFallbackModelContainer() -> ModelContainer {
        do {
            let schema = Schema([TranscriptionRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create fallback ModelContainer: \(error)")
        }
    }

    @objc func restoreFocusToPreviousApp() {
        windowController.restoreFocusToPreviousApp()
    }
}
