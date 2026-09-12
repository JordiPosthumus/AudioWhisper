import XCTest
import ServiceManagement
@testable import AudioWhisper

@MainActor
final class LoginItemManagerTests: XCTestCase {
    private func preferences() -> UserDefaults {
        let name = "ScribeKitt.LoginTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testNewUserStaysOffWithoutRegistrationOrPreferenceWrite() {
        let defaults = preferences()
        let service = LoginItemServiceFixture()
        let manager = service.manager(defaults)
        manager.refresh()
        XCTAssertFalse(manager.isEnabled)
        XCTAssertNil(defaults.object(forKey: AppDefaults.Keys.startAtLogin))
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.unregistrations, 0)
    }

    func testUpgradePreservesEnabledRegistrationEvenWithoutSavedPreference() {
        let service = LoginItemServiceFixture(.enabled)
        let manager = service.manager(preferences())
        manager.refresh()
        XCTAssertTrue(manager.isEnabled)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.unregistrations, 0)
    }

    func testSystemDisableOverridesStalePreferenceWithoutReregistering() {
        let defaults = preferences()
        defaults.set(true, forKey: AppDefaults.Keys.startAtLogin)
        let service = LoginItemServiceFixture(.enabled)
        let manager = service.manager(defaults)
        service.status = .requiresApproval
        manager.refresh()
        XCTAssertFalse(manager.isEnabled)
        XCTAssertTrue(manager.needsApproval)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertTrue(defaults.bool(forKey: AppDefaults.Keys.startAtLogin))
    }

    func testExplicitEnableAndDisableFollowActualStatus() async {
        let defaults = preferences()
        let service = LoginItemServiceFixture()
        let manager = service.manager(defaults)
        await manager.setEnabled(true)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertTrue(defaults.bool(forKey: AppDefaults.Keys.startAtLogin))
        await manager.setEnabled(false)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(defaults.bool(forKey: AppDefaults.Keys.startAtLogin))
        XCTAssertEqual(service.registrations, 1)
        XCTAssertEqual(service.unregistrations, 1)
    }

    func testFailedDisableKeepsToggleOnAndPreservesSavedChoice() async {
        let defaults = preferences()
        defaults.set(true, forKey: AppDefaults.Keys.startAtLogin)
        let service = LoginItemServiceFixture(.enabled)
        service.failure = true
        let manager = service.manager(defaults)
        await manager.setEnabled(false)
        XCTAssertTrue(manager.isEnabled)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertTrue(defaults.bool(forKey: AppDefaults.Keys.startAtLogin))
        XCTAssertFalse(manager.isUpdating)
    }

    func testFailedEnableStaysOffAndDoesNotPersistSuccess() async {
        let defaults = preferences()
        let service = LoginItemServiceFixture()
        service.failure = true
        let manager = service.manager(defaults)
        await manager.setEnabled(true)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertNil(defaults.object(forKey: AppDefaults.Keys.startAtLogin))
    }

    func testApprovalIsNotReportedAsEnabledAndCanBeCancelled() async {
        let service = LoginItemServiceFixture()
        service.registrationStatus = .requiresApproval
        let manager = service.manager(preferences())
        await manager.setEnabled(true)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertTrue(manager.needsApproval)
        XCTAssertNil(manager.errorMessage)
        await manager.setEnabled(true)
        XCTAssertEqual(service.registrations, 1)
        manager.openLoginSettings()
        XCTAssertEqual(service.settingsOpens, 1)
        await manager.setEnabled(false)
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertFalse(manager.needsApproval)
    }

    func testExternalApprovalAndRemovalRefreshWithoutMutation() {
        let service = LoginItemServiceFixture(.requiresApproval)
        let manager = service.manager(preferences())
        service.status = .enabled
        manager.refresh()
        XCTAssertTrue(manager.isEnabled)
        service.status = .notRegistered
        manager.refresh()
        XCTAssertFalse(manager.isEnabled)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.unregistrations, 0)
    }

    func testUnconfirmedRegistrationNeverShowsSuccess() async {
        let service = LoginItemServiceFixture()
        service.registrationStatus = .notFound
        let defaults = preferences()
        let manager = service.manager(defaults)
        await manager.setEnabled(true)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertNil(defaults.object(forKey: AppDefaults.Keys.startAtLogin))
    }

    func testRepeatedClicksCannotOverlapUnregistration() async {
        let service = LoginItemServiceFixture(.enabled)
        service.delay = true
        let manager = service.manager(preferences())
        let first = Task { await manager.setEnabled(false) }
        while !manager.isUpdating { await Task.yield() }
        await manager.setEnabled(false)
        await first.value
        XCTAssertEqual(service.unregistrations, 1)
        XCTAssertFalse(manager.isEnabled)
        XCTAssertFalse(manager.isUpdating)
    }
}

@MainActor
private final class LoginItemServiceFixture {
    var status: SMAppService.Status
    var registrationStatus: SMAppService.Status = .enabled
    var registrations = 0, unregistrations = 0, settingsOpens = 0
    var failure = false, delay = false

    init(_ status: SMAppService.Status = .notRegistered) { self.status = status }

    func manager(_ defaults: UserDefaults) -> LoginItemManager {
        LoginItemManager(defaults: defaults, readStatus: { self.status }, register: {
            self.registrations += 1
            if self.failure { throw CocoaError(.fileWriteNoPermission) }
            self.status = self.registrationStatus
        }, unregister: {
            self.unregistrations += 1
            if self.delay { try await Task.sleep(for: .milliseconds(40)) }
            if self.failure { throw CocoaError(.fileWriteNoPermission) }
            self.status = .notRegistered
        }, openSettings: { self.settingsOpens += 1 })
    }
}
