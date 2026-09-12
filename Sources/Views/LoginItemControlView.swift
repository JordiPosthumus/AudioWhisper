import AppKit
import SwiftUI

internal struct LoginItemControlView: View {
    @ObservedObject var manager: LoginItemManager = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(get: { manager.isEnabled }, set: { enabled in
                Task { await manager.setEnabled(enabled) }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at Login")
                    Text("Keep ScribeKitt ready in the menu bar when you sign in.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(manager.isUpdating)

            if manager.needsApproval {
                Text("Off in macOS. Allow ScribeKitt in Login Settings to enable it.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Open Login Settings") { manager.openLoginSettings() }
                    Button("Cancel Request") { Task { await manager.setEnabled(false) } }
                        .disabled(manager.isUpdating)
                }
            } else if manager.status == .notFound {
                Text("macOS couldn’t locate ScribeKitt’s login item.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let message = manager.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
                if !manager.needsApproval {
                    Button("Open Login Settings") { manager.openLoginSettings() }
                }
            }
        }
        .onAppear { manager.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in manager.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in manager.refresh() }
    }
}
