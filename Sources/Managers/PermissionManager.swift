import AppKit
import AVFoundation
import Observation

internal enum PermissionState {
    case unknown
    case notRequested
    case requesting
    case granted
    case denied
    case restricted
    
    var needsRequest: Bool {
        switch self {
        case .unknown, .notRequested:
            return true
        default:
            return false
        }
    }
    
    var canRetry: Bool {
        switch self {
        case .denied:
            return true
        default:
            return false
        }
    }
}

@MainActor
@Observable
internal class PermissionManager {
    var microphonePermissionState: PermissionState = .unknown
    var showEducationalModal = false
    var showRecoveryModal = false
    private let isTestEnvironment: Bool
    
    var allPermissionsGranted: Bool { microphonePermissionState == .granted }

    init(defaults: UserDefaults = .standard) {
        // Detect if running in tests
        isTestEnvironment = NSClassFromString("XCTestCase") != nil
    }
    
    func checkPermissionState() {
        checkMicrophonePermission()
    }

    private func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            self.microphonePermissionState = .granted
        case .denied:
            self.microphonePermissionState = .denied
        case .restricted:
            self.microphonePermissionState = .restricted
        case .notDetermined:
            self.microphonePermissionState = .notRequested
        @unknown default:
            self.microphonePermissionState = .unknown
        }
    }
    
    func requestPermissionWithEducation() {
        if microphonePermissionState.needsRequest {
            showEducationalModal = true
        } else if microphonePermissionState.canRetry {
            showRecoveryModal = true
        }
    }

    func proceedWithPermissionRequest() {
        if isTestEnvironment {
            // In tests, simulate permission behavior without actual system dialog
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                // Simulate denied for consistent test behavior
                self.microphonePermissionState = .denied
                self.showRecoveryModal = true
            }
        } else {
            requestMicrophonePermission()
            
        }
    }

    private func requestMicrophonePermission() {
        if microphonePermissionState.needsRequest {
            microphonePermissionState = .requesting
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.microphonePermissionState = granted ? .granted : .denied
                    self?.checkIfAllPermissionsHandled()
                }
            }
        }
    }
    
    private func checkIfAllPermissionsHandled() {
        let hasFailures = microphonePermissionState == .denied
        if hasFailures && !showRecoveryModal {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                self.showRecoveryModal = true
            }
        }
    }
    
    func openSystemSettings() {
        // Skip actual system settings in test environment
        if isTestEnvironment {
            return
        }
        
        // Open the microphone permission pane directly
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
