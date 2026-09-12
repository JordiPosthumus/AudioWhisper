import SwiftUI
import AVFoundation

internal struct ContentView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @AppStorage(AppDefaults.Keys.immediateRecording) var immediateRecording = false
    @State var parakeetService: ParakeetService
    @State var statusViewModel = StatusViewModel()
    @State var permissionManager = PermissionManager()
    @StateObject var soundManager = SoundManager()
    @State var isProcessing = false
    @State var progressMessage = "Processing..."
    @State var transcriptionStartTime: Date?
    @State var showError = false
    @State var errorMessage = ""
    @State var showSuccess = false
    @State var isHovered = false
    @State var isHandlingSpaceKey = false
    @State var processingTask: Task<Void, Never>?
    @State var transcriptionProgressObserver: NSObjectProtocol?
    @State var spaceKeyObserver: NSObjectProtocol?
    @State var escapeKeyObserver: NSObjectProtocol?
    @State var recordingFailedObserver: NSObjectProtocol?
    @State var windowFocusObserver: NSObjectProtocol?
    @State var retryObserver: NSObjectProtocol?
    @State var showAudioFileObserver: NSObjectProtocol?
    @State var transcribeFileObserver: NSObjectProtocol?
    @State var lastAudioURL: URL?
    
    @State var activeTranscriptionID: UUID?

    init(parakeetService: ParakeetService = ParakeetService(), audioRecorder: AudioRecorder) {
        self._parakeetService = State(initialValue: parakeetService)
        self.audioRecorder = audioRecorder
    }
    
    private func showErrorAlert() {
        ErrorPresenter.shared.showError(errorMessage)
        showError = false
    }
    
    var body: some View {
        FloatingRecorderView(
            status: statusViewModel.currentStatus,
            audioLevel: audioRecorder.audioLevel,
            recordingStartedAt: audioRecorder.currentSessionStart,
            onPrimaryAction: {
                if audioRecorder.isRecording { stopAndProcess() }
                else if !isProcessing { startRecording() }
            },
            onDismiss: dismissRecorder
        )
        .sheet(isPresented: $permissionManager.showEducationalModal) {
            PermissionEducationModal(
                onProceed: {
                    permissionManager.showEducationalModal = false
                    permissionManager.proceedWithPermissionRequest()
                },
                onCancel: {
                    permissionManager.showEducationalModal = false
                }
            )
        }
        .sheet(isPresented: $permissionManager.showRecoveryModal) {
            PermissionRecoveryModal(
                onOpenSettings: {
                    permissionManager.showRecoveryModal = false
                    permissionManager.openSystemSettings()
                },
                onCancel: {
                    permissionManager.showRecoveryModal = false
                }
            )
        }
        .focusable(false)
        .onAppear { handleOnAppear() }
        .onDisappear { handleOnDisappear() }
        .onChange(of: audioRecorder.isRecording) { _, isRecording in
            if isRecording { recordingSessionDidStart() }
            updateStatus()
            updateRecordingWindowSize()
        }
        .onChange(of: isProcessing) { _, _ in
            updateStatus()
        }
        .onChange(of: progressMessage) { _, _ in
            updateStatus()
        }
        .onChange(of: audioRecorder.hasPermission) { _, _ in
            updateStatus()
        }
        .onChange(of: showSuccess) { _, _ in
            updateStatus()
            updateRecordingWindowSize()
        }
        .onChange(of: showError) { _, newValue in
            updateStatus()
            if newValue {
                showErrorAlert()
            }
        }
        .onChange(of: permissionManager.allPermissionsGranted) { _, _ in
            audioRecorder.hasPermission = (permissionManager.microphonePermissionState == .granted)
            updateStatus()
        }
    }
}
