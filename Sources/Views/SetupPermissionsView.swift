import SwiftUI

internal struct SetupPermissionsView: View {
    @ObservedObject var permissions: SetupPermissions
    var configuration: PressAndHoldConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Microphone", systemImage: permissions.microphoneAllowed ? "checkmark.circle.fill" : "mic")
                Spacer()
                if permissions.microphoneAllowed { Text("Allowed").foregroundStyle(.secondary) }
                else {
                    Button("Allow Microphone") { Task { await permissions.allowMicrophone() } }
                        .disabled(permissions.requestingMicrophone)
                }
            }
            if configuration.enabled {
                HStack {
                    Label("Recording key", systemImage: permissions.keyboardAllowed ? "checkmark.circle.fill" : "keyboard")
                    Spacer()
                    if permissions.keyboardAllowed { Text("Allowed").foregroundStyle(.secondary) }
                    else { Button("Allow in Settings") { permissions.allowKeyboard() } }
                }
                Text("Enable ScribeKitt in Privacy & Security → Accessibility so \(configuration.key.displayName) works in other apps. Use the + button to add ScribeKitt from Applications if it isn’t listed.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(SetupPermissions.restartNote)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13))
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in permissions.refresh() }
    }
}
