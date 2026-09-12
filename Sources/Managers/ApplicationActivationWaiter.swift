import AppKit

/// Owns an activation observer until either the requested app activates or the timeout fires.
@MainActor
internal final class ApplicationActivationWaiter {
    private let center: NotificationCenter
    private let target: NSRunningApplication
    private var observer: NSObjectProtocol?
    private var timeout: DispatchWorkItem?
    private var completion: ((Bool) -> Void)?

    private init(target: NSRunningApplication, center: NotificationCenter, completion: @escaping (Bool) -> Void) {
        self.target = target
        self.center = center
        self.completion = completion
    }

    static func wait(
        for target: NSRunningApplication,
        center: NotificationCenter = NSWorkspace.shared.notificationCenter,
        timeout: TimeInterval = 0.3,
        completion: @escaping (Bool) -> Void
    ) {
        guard !target.isActive else { completion(true); return }
        let waiter = ApplicationActivationWaiter(target: target, center: center, completion: completion)
        waiter.start(timeout: timeout)
    }

    private func start(timeout interval: TimeInterval) {
        observer = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [self] notification in
            MainActor.assumeIsolated {
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier == target.processIdentifier else { return }
                finish(activated: true)
            }
        }
        let work = DispatchWorkItem { [self] in
            MainActor.assumeIsolated { finish(activated: target.isActive) }
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
        // Cover activation between the initial check and observer registration.
        if target.isActive { finish(activated: true) }
    }

    private func finish(activated: Bool) {
        guard let completion else { return }
        self.completion = nil
        if let observer { center.removeObserver(observer) }
        observer = nil
        timeout?.cancel()
        timeout = nil
        completion(activated)
    }
}
