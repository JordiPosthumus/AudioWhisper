import SwiftUI
import AppKit
import AVFoundation

@MainActor
internal extension ContentView {
    func startRecording() {
        guard !isProcessing else { return }
        guard audioRecorder.hasPermission else {
            permissionManager.requestPermissionWithEducation()
            return
        }
        lastAudioURL = nil
        showSuccess = false
        pasteMessage = nil
        if !audioRecorder.startRecording() {
            errorMessage = LocalizedStrings.Errors.failedToStartRecording
            showError = true
        }
    }

    func stopAndProcess() {
        guard let audioURL = audioRecorder.stopRecording() else {
            errorMessage = LocalizedStrings.Errors.failedToGetRecordingURL
            showError = true
            return
        }
        NotificationCenter.default.post(name: .recordingStopped, object: nil)
        processAudio(audioURL, duration: audioRecorder.lastRecordingDuration)
    }

    func transcribeExternalAudioFile(_ audioURL: URL) {
        guard !audioRecorder.isRecording else { return }
        processAudio(audioURL, duration: nil)
    }

    private func processAudio(_ audioURL: URL, duration: TimeInterval?) {
        processingTask?.cancel()
        let requestID = UUID()
        activeTranscriptionID = requestID
        isProcessing = true
        showSuccess = false
        transcriptionStartTime = Date()
        progressMessage = "Transcribing..."
        lastAudioURL = audioURL

        processingTask = Task {
            do {
                try Task.checkCancellation()
                let validation = await AudioValidator.validateAudioFile(at: audioURL)
                if case .invalid(let error) = validation { throw error }
                try Task.checkCancellation()
                let text = try await parakeetService.transcribe(audioFileURL: audioURL)
                try Task.checkCancellation()
                guard activeTranscriptionID == requestID else { return }

                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                if DataManager.shared.isHistoryEnabled {
                    let record = TranscriptionRecord(
                        text: text,
                        provider: .parakeet,
                        duration: duration,
                        modelUsed: ParakeetModel.v2English.rawValue
                    )
                    await DataManager.shared.saveTranscriptionQuietly(record)
                }
                guard activeTranscriptionID == requestID else { return }
                transcriptionStartTime = nil
                showConfirmationAndPaste(text: text)
            } catch is CancellationError {
                guard activeTranscriptionID == requestID else { return }
                isProcessing = false
                transcriptionStartTime = nil
            } catch {
                guard activeTranscriptionID == requestID else { return }
                errorMessage = error.localizedDescription
                showError = true
                isProcessing = false
                transcriptionStartTime = nil
            }
        }
    }

    func showConfirmationAndPaste(text: String) {
        previewText = text
        pasteMessage = nil
        showSuccess = true
        isProcessing = false
        soundManager.playCompletionSound()
        updateRecordingWindowSize()
        showPreviewWindow()
    }

    func recordingSessionDidStart() {
        processingTask?.cancel()
        processingTask = nil
        activeTranscriptionID = nil
        pasteTask?.cancel()
        pasteTask = nil
        isPasting = false
        isProcessing = false
        transcriptionStartTime = nil
        previewText = ""
        pasteMessage = nil
        showSuccess = false
    }

    func retryLastTranscription() {
        guard !isProcessing, !audioRecorder.isRecording else { return }
        guard let audioURL = lastAudioURL, FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "No recording is available to retry. Please record again."
            showError = true
            return
        }
        processAudio(audioURL, duration: audioRecorder.lastRecordingDuration)
    }

    func showLastAudioFile() {
        guard let audioURL = lastAudioURL, FileManager.default.fileExists(atPath: audioURL.path) else {
            errorMessage = "The recording is no longer available."
            showError = true
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([audioURL])
    }
}
