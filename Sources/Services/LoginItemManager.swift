import Combine
import Foundation
import ServiceManagement
import os.log

@MainActor
internal final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () async throws -> Void
    private let openSettings: () -> Void

    var isEnabled: Bool { status == .enabled }
    var needsApproval: Bool { status == .requiresApproval }

    init(defaults: UserDefaults = .standard,
         readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () async throws -> Void = { try await SMAppService.mainApp.unregister() },
         openSettings: @escaping () -> Void = { SMAppService.openSystemSettingsLoginItems() }) {
        self.defaults = defaults
        self.readStatus = readStatus
        self.register = register
        self.unregister = unregister
        self.openSettings = openSettings
        // macOS owns the effective setting. Never register/unregister at startup
        // or replay an old preference over a choice made in System Settings.
        status = readStatus()
    }

    func refresh() {
        let current = readStatus()
        if current != status { errorMessage = nil }
        status = current
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }
        do {
            refresh()
            if enabled {
                if status != .enabled && status != .requiresApproval { try register() }
            } else if status != .notRegistered {
                try await unregister()
            }
            refresh()
            guard (enabled && (isEnabled || needsApproval)) || (!enabled && status == .notRegistered) else {
                throw NSError(domain: "ScribeKitt.LoginItem", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "macOS did not confirm the change. Please check Login Settings."])
            }
            // Retain the legacy preference for compatibility, but never use it
            // as evidence that macOS has enabled launch at login.
            defaults.set(enabled, forKey: AppDefaults.Keys.startAtLogin)
        } catch {
            refresh()
            errorMessage = "Couldn’t turn \(enabled ? "on" : "off") Start at Login. \(error.localizedDescription)"
            Logger.settings.error("Login item change failed: \(error.localizedDescription)")
        }
    }

    func openLoginSettings() { openSettings() }
}
