import SwiftUI

internal struct PermissionEducationModal: View {
    let onProceed: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill").font(.largeTitle).foregroundStyle(.blue)
            Text("Microphone Access").font(.title2).fontWeight(.semibold)
            Text("Allow SpeedyWhisper to record your voice for local transcription.")
                .multilineTextAlignment(.center)
            HStack {
                Button("Not Now", action: onCancel)
                Button("Allow Microphone Access", action: onProceed).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

internal struct PermissionRecoveryModal: View {
    let onOpenSettings: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.slash").font(.largeTitle).foregroundStyle(.orange)
            Text("Microphone Access Is Off").font(.title2).fontWeight(.semibold)
            Text("Open Microphone Settings and enable SpeedyWhisper. It may appear under its original name, AudioWhisper.")
                .multilineTextAlignment(.center)
            HStack {
                Button("Cancel", action: onCancel)
                Button("Open Microphone Settings", action: onOpenSettings).buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
