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
        finalText = nil
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
        completionTask?.cancel()
        finalText = nil
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

                guard TranscriptClipboard.copy(text) else {
                    throw NSError(domain: "SpeedyWhisper.Clipboard", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not copy the transcript. Please retry."])
                }
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
                finishTranscription(text: text, requestID: requestID)
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

    func finishTranscription(text: String, requestID: UUID) {
        isProcessing = false
        finalText = text
        showSuccess = true
        soundManager.playCompletionSound()
        updateRecordingWindowSize()
        // A brief confirmation never takes keyboard focus or sends a paste event.
        NSApp.windows.first { $0.title == AppBrand.recordingWindowTitle }?.orderFrontRegardless()
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(TranscriptPresentation.duration(for: text))) }
            catch { return }
            guard activeTranscriptionID == requestID, !audioRecorder.isRecording, !isProcessing else { return }
            hideRecordingWindow()
            showSuccess = false
            finalText = nil
        }
    }

    func recordingSessionDidStart() {
        completionTask?.cancel()
        completionTask = nil
        finalText = nil
        processingTask?.cancel()
        processingTask = nil
        activeTranscriptionID = nil
        isProcessing = false
        transcriptionStartTime = nil
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
