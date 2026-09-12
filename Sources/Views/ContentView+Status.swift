import SwiftUI

internal extension ContentView {
    func enhanceProgressMessage(_ message: String) -> String { message }

    func updateStatus() {
        statusViewModel.updateStatus(
            isRecording: audioRecorder.isRecording,
            isProcessing: isProcessing,
            modelDownloadMessage: nil,
            progressMessage: progressMessage,
            hasPermission: audioRecorder.hasPermission,
            showSuccess: showSuccess,
            errorMessage: showError ? errorMessage : nil
        )
    }
}
