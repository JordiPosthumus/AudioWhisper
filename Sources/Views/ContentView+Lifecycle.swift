import SwiftUI
import AppKit

@MainActor
internal extension ContentView {
    func handleOnAppear() {
        audioRecorder.checkMicrophonePermission()
        setupNotificationObservers()
        permissionManager.checkPermissionState()
        updateStatus()
        updateRecordingWindowSize()
    }
    
    func handleOnDisappear() {
        completionTask?.cancel()
        completionTask = nil
        removeNotificationObservers()
        processingTask?.cancel()
        processingTask = nil
        activeTranscriptionID = nil
        lastAudioURL = nil
    }
    
    private func setupNotificationObservers() {
        transcriptionProgressObserver = NotificationCenter.default.addObserver(
            forName: .transcriptionProgress,
            object: nil,
            queue: .main
        ) { notification in
            Task { @MainActor in
                if let message = notification.object as? String {
                    progressMessage = enhanceProgressMessage(message)
                }
            }
        }
        
        spaceKeyObserver = NotificationCenter.default.addObserver(
            forName: .spaceKeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard !isHandlingSpaceKey else { return }
                isHandlingSpaceKey = true
                
                if audioRecorder.isRecording {
                    stopAndProcess()
                } else if !isProcessing && audioRecorder.hasPermission && !showSuccess {
                    startRecording()
                } else if !audioRecorder.hasPermission {
                    permissionManager.requestPermissionWithEducation()
                }
                
                try? await Task.sleep(for: .seconds(1))
                isHandlingSpaceKey = false
            }
        }
        
        escapeKeyObserver = NotificationCenter.default.addObserver(
            forName: .escapeKeyPressed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                dismissRecorder()
            }
        }
        
        recordingFailedObserver = NotificationCenter.default.addObserver(
            forName: .recordingStartFailed,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                errorMessage = LocalizedStrings.Errors.failedToStartRecording
                showError = true
            }
        }
        
        retryObserver = NotificationCenter.default.addObserver(
            forName: .retryTranscriptionRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in retryLastTranscription() }
        }
        
        showAudioFileObserver = NotificationCenter.default.addObserver(
            forName: .showAudioFileRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in showLastAudioFile() }
        }
        
        transcribeFileObserver = NotificationCenter.default.addObserver(
            forName: .transcribeAudioFile,
            object: nil,
            queue: .main
        ) { notification in
            if let url = notification.object as? URL {
                Task { @MainActor in transcribeExternalAudioFile(url) }
            }
        }
    }
    
    private func removeNotificationObservers() {
        removeObserver(&transcriptionProgressObserver)
        removeObserver(&spaceKeyObserver)
        removeObserver(&escapeKeyObserver)
        removeObserver(&recordingFailedObserver)
        removeObserver(&windowFocusObserver)
        removeObserver(&retryObserver)
        removeObserver(&showAudioFileObserver)
        removeObserver(&transcribeFileObserver)
    }
    
    private func removeObserver(_ observer: inout NSObjectProtocol?) {
        if let existing = observer {
            NotificationCenter.default.removeObserver(existing)
            observer = nil
        }
    }
    
}
