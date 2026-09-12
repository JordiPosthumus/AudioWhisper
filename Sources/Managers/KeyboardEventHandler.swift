import Foundation
import AppKit

internal class KeyboardEventHandler {
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private let isTestEnvironment: Bool
    
    init(isTestEnvironment: Bool = NSClassFromString("XCTestCase") != nil) {
        self.isTestEnvironment = isTestEnvironment
        
        // Avoid installing global monitors in tests to prevent flaky AppKit interactions
        if !isTestEnvironment {
            setupGlobalKeyMonitoring()
        }
    }
    
    private func setupGlobalKeyMonitoring() {
        // Passive observation never consumes another app's paste. macOS supplies
        // global key events only when its existing Accessibility access allows it.
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard let window = NSApp.windows.first(where: { $0.title == AppBrand.recordingWindowTitle }),
                  window.isVisible else { return }
            if Self.isPasteShortcut(event) {
                Self.notifyPasteShortcut()
            } else if event.keyCode == 53 {
                NotificationCenter.default.post(name: .escapeKeyPressed, object: nil)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let window = NSApp.windows.first(where: { $0.title == AppBrand.recordingWindowTitle }),
                  window.isVisible, window.isKeyWindow else { return event }
            return self.handleKeyEvent(event, for: window)
        }
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent, for window: NSWindow) -> NSEvent? {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        let modifiers = event.modifierFlags

        if Self.isPasteShortcut(event) {
            Self.notifyPasteShortcut()
            return event
        }
        
        // Handle space key
        if key == " " && !modifiers.contains(.command) {
            NotificationCenter.default.post(name: .spaceKeyPressed, object: nil)
            return nil // Consume the event
        }
        
        // Handle escape key
        if key == String(Character(UnicodeScalar(27)!)) { // Escape
            NotificationCenter.default.post(name: .escapeKeyPressed, object: nil)
            return nil // Consume the event
        }
        
        // Allow ⌘, for opening dashboard/settings replacement
        if key == "," && modifiers.contains(.command) {
            Task { @MainActor in
                DashboardWindowManager.shared.showDashboardWindow()
            }
            return nil // Consume the event
        }
        
        // Preserve native selection/copy shortcuts in the transcript preview.
        
        // Allow non-command keys to pass through
        return event
    }

    static func isPasteShortcut(_ event: NSEvent) -> Bool {
        event.type == .keyDown && !event.isARepeat &&
        event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.control) &&
        event.charactersIgnoringModifiers?.lowercased() == "v"
    }

    private static func notifyPasteShortcut() {
        NotificationCenter.default.post(name: .transcriptPasteShortcut, object: nil,
            userInfo: ["pasteboardChangeCount": NSPasteboard.general.changeCount])
    }
    
    deinit {
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
}
