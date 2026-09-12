import AppKit
import os.log

internal extension AppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Skip UI initialization in test environment
        let isTestEnvironment = NSClassFromString("XCTestCase") != nil
        if isTestEnvironment {
            Logger.app.info("Test environment detected - skipping UI initialization")
            return
        }

        // Ensure a single, consistent set of defaults before any UI/services read from UserDefaults/AppStorage.
        AppDefaults.register()

        do {
            try DataManager.shared.initialize()
            Logger.app.info("DataManager initialized successfully")
        } catch {
            Logger.app.error("Failed to initialize DataManager: \(error.localizedDescription)")
            // App continues with in-memory fallback
        }


        AppSetupHelper.setupApp()

        // New installs finish setup before asking for microphone access.
        // Established installs retain their normal recorder initialization.
        if LocalSetupManager.shared.isReady {
            audioRecorder = AudioRecorder()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = AppSetupHelper.createMenuBarIcon()
            button.action = #selector(toggleRecordWindow)
            button.target = self
        }
        statusItem?.menu = makeStatusMenu()

        hotKeyManager = HotKeyManager { [weak self] in
            self?.handleHotkey(source: .standardHotkey)
        }
        keyboardEventHandler = KeyboardEventHandler()
        configureShortcutMonitors()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        setupNotificationObservers()

        if !LocalSetupManager.shared.isReady {
            showLocalSetup()
        }

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep app running in menu bar
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { await MLDaemonManager.shared.shutdown() }
        recordingAnimationTimer?.cancel()
        recordingAnimationTimer = nil

        recordingWindow = nil
        recordingWindowDelegate = nil

        AppSetupHelper.cleanupOldTemporaryFiles()
    }

}
