import AppKit

internal extension AppDelegate {
    func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardAccessChanged),
                                               name: SetupPermissions.keyboardAccessChanged, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDashboard),
            name: .welcomeCompleted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restoreFocusToPreviousApp),
            name: .restoreFocusToPreviousApp,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onRecordingStopped),
            name: .recordingStopped,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPressAndHoldSettingsChanged(_:)),
            name: .pressAndHoldSettingsChanged,
            object: nil
        )
    }

    @objc private func onKeyboardAccessChanged() {
        // Reinstall monitors after permission is granted, without interrupting a hold.
        guard !isHoldRecordingActive else { return }
        configureShortcutMonitors()
    }

    @objc private func onPressAndHoldSettingsChanged(_ notification: Notification) {
        configureShortcutMonitors()
    }
}
