import AppKit

// Lightweight mock of NSRunningApplication used by PasteManager tests
final class MockRunningApplication: NSRunningApplication {
    var mockIsTerminated: Bool = false
    var mockActivationCount: Int = 0
    var mockIsActive = false
    var mockProcessIdentifier: pid_t = 123

    override var isActive: Bool { mockIsActive }
    override var processIdentifier: pid_t { mockProcessIdentifier }

    override var isTerminated: Bool { mockIsTerminated }

    override func activate(options: NSApplication.ActivationOptions = []) -> Bool {
        mockActivationCount += 1
        return true
    }
}

