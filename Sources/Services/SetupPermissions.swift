import AppKit
import AVFoundation
import Combine
import ApplicationServices

@MainActor
internal final class SetupPermissions: ObservableObject {
    static let shared = SetupPermissions()
    static let keyboardAccessChanged = Notification.Name("ScribeKitt.keyboardAccessChanged")
    static let restartNote = "If the recording key still doesn’t respond after granting access, quit ScribeKitt from the microphone menu and reopen it."

    @Published private(set) var microphone: AVAuthorizationStatus
    @Published private(set) var keyboardAllowed: Bool
    @Published private(set) var requestingMicrophone = false
    private let readMicrophone: () -> AVAuthorizationStatus
    private let readKeyboard: () -> Bool
    private let requestMicrophone: () async -> Bool
    private let openKeyboard: () -> Void
    private let openMicrophone: () -> Void

    var microphoneAllowed: Bool { microphone == .authorized }
    func needsSetup(configuration: PressAndHoldConfiguration) -> Bool {
        !microphoneAllowed || (configuration.enabled && !keyboardAllowed)
    }

    init(readMicrophone: @escaping () -> AVAuthorizationStatus = { AVCaptureDevice.authorizationStatus(for: .audio) },
         readKeyboard: @escaping () -> Bool = { AXIsProcessTrusted() },
         requestMicrophone: @escaping () async -> Bool = { await AVCaptureDevice.requestAccess(for: .audio) },
         openKeyboard: @escaping () -> Void = {
             let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
             _ = AXIsProcessTrustedWithOptions(options)
             NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
         },
         openMicrophone: @escaping () -> Void = {
             NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
         }) {
        self.readMicrophone = readMicrophone
        self.readKeyboard = readKeyboard
        self.requestMicrophone = requestMicrophone
        self.openKeyboard = openKeyboard
        self.openMicrophone = openMicrophone
        microphone = readMicrophone()
        keyboardAllowed = readKeyboard()
    }

    func refresh() {
        microphone = readMicrophone()
        let allowed = readKeyboard()
        let changed = keyboardAllowed != allowed
        keyboardAllowed = allowed
        if changed { NotificationCenter.default.post(name: Self.keyboardAccessChanged, object: self) }
    }

    func allowMicrophone() async {
        guard !requestingMicrophone else { return }
        refresh()
        if microphone == .notDetermined {
            requestingMicrophone = true
            _ = await requestMicrophone()
            requestingMicrophone = false
            refresh()
        } else if !microphoneAllowed {
            openMicrophone()
        }
    }

    func allowKeyboard() { openKeyboard() }
}
