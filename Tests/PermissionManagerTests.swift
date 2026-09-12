import XCTest
@testable import AudioWhisper

@MainActor
final class PermissionManagerTests: XCTestCase {

    var permissionManager: PermissionManager!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "PermissionManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        permissionManager = PermissionManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        permissionManager = nil
        super.tearDown()
    }

    // MARK: - PermissionState Tests

    func testPermissionStateNeedsRequest() {
        XCTAssertTrue(PermissionState.unknown.needsRequest)
        XCTAssertTrue(PermissionState.notRequested.needsRequest)
        XCTAssertFalse(PermissionState.requesting.needsRequest)
        XCTAssertFalse(PermissionState.granted.needsRequest)
        XCTAssertFalse(PermissionState.denied.needsRequest)
        XCTAssertFalse(PermissionState.restricted.needsRequest)
    }

    func testPermissionStateCanRetry() {
        XCTAssertFalse(PermissionState.unknown.canRetry)
        XCTAssertFalse(PermissionState.notRequested.canRetry)
        XCTAssertFalse(PermissionState.requesting.canRetry)
        XCTAssertFalse(PermissionState.granted.canRetry)
        XCTAssertTrue(PermissionState.denied.canRetry)
        XCTAssertFalse(PermissionState.restricted.canRetry)
    }

    // MARK: - PermissionManager Initial State Tests

    func testInitialState() {
        XCTAssertEqual(permissionManager.microphonePermissionState, .unknown)
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    // MARK: - Modal State Logic Tests

    func testRequestPermissionWithEducationForNewPermission() {
        permissionManager.microphonePermissionState = .notRequested

        permissionManager.requestPermissionWithEducation()

        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    func testRequestPermissionWithEducationForDeniedPermission() {
        permissionManager.microphonePermissionState = .denied

        permissionManager.requestPermissionWithEducation()

        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertTrue(permissionManager.showRecoveryModal)
    }

    func testRequestPermissionWithEducationForGrantedPermission() {
        permissionManager.microphonePermissionState = .granted

        permissionManager.requestPermissionWithEducation()

        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    // MARK: - State Transition Tests

    func testStateTransitions() {
        // Test valid state transitions for microphone permission
        permissionManager.microphonePermissionState = .unknown
        XCTAssertEqual(permissionManager.microphonePermissionState, .unknown)

        permissionManager.microphonePermissionState = .notRequested
        XCTAssertEqual(permissionManager.microphonePermissionState, .notRequested)

        permissionManager.microphonePermissionState = .requesting
        XCTAssertEqual(permissionManager.microphonePermissionState, .requesting)

        permissionManager.microphonePermissionState = .granted
        XCTAssertEqual(permissionManager.microphonePermissionState, .granted)

        permissionManager.microphonePermissionState = .denied
        XCTAssertEqual(permissionManager.microphonePermissionState, .denied)

        permissionManager.microphonePermissionState = .restricted
        XCTAssertEqual(permissionManager.microphonePermissionState, .restricted)

    }

    func testModalStateManagement() {
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)

        permissionManager.showEducationalModal = true
        XCTAssertTrue(permissionManager.showEducationalModal)

        permissionManager.showRecoveryModal = true
        XCTAssertTrue(permissionManager.showRecoveryModal)

        permissionManager.showEducationalModal = false
        permissionManager.showRecoveryModal = false
        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    // MARK: - Edge Cases

    func testRequestPermissionInRestrictedState() {
        permissionManager.microphonePermissionState = .restricted

        permissionManager.requestPermissionWithEducation()

        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    func testRequestPermissionWhileAlreadyRequesting() {
        permissionManager.microphonePermissionState = .requesting

        permissionManager.requestPermissionWithEducation()

        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)
    }

    // MARK: - Performance Tests

    func testPermissionStateCheckPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = PermissionState.unknown.needsRequest
                _ = PermissionState.denied.canRetry
                _ = PermissionState.granted.needsRequest
            }
        }
    }

    // MARK: - Multiple Instance Tests

    func testMultiplePermissionManagerInstances() {
        let manager1 = PermissionManager()
        let manager2 = PermissionManager()

        manager1.microphonePermissionState = .granted
        manager2.microphonePermissionState = .denied

        XCTAssertEqual(manager1.microphonePermissionState, .granted)
        XCTAssertEqual(manager2.microphonePermissionState, .denied)

        manager1.showEducationalModal = true
        manager2.showRecoveryModal = true

        XCTAssertTrue(manager1.showEducationalModal)
        XCTAssertFalse(manager1.showRecoveryModal)
        XCTAssertFalse(manager2.showEducationalModal)
        XCTAssertTrue(manager2.showRecoveryModal)
    }

    // MARK: - AllPermissionsGranted Tests

    func testAllPermissionsGrantedWithSmartPasteDisabled() {
        // When SmartPaste is disabled, only microphone permission is required
        defaults.set(false, forKey: "enableSmartPaste")

        permissionManager.microphonePermissionState = .granted

        XCTAssertTrue(permissionManager.allPermissionsGranted)

        // Clean up
        defaults.removeObject(forKey: "enableSmartPaste")
    }

    func testLegacySmartPastePreferenceDoesNotRequireAdditionalPermission() {
        // A stale setting from an earlier build must not gate manual clipboard use.
        defaults.set(true, forKey: "enableSmartPaste")

        permissionManager.microphonePermissionState = .granted

        XCTAssertTrue(permissionManager.allPermissionsGranted)

        XCTAssertTrue(permissionManager.allPermissionsGranted)

        // Clean up
        defaults.removeObject(forKey: "enableSmartPaste")
    }

    func testAllPermissionsGrantedWithMicrophoneDenied() {
        // Microphone permission is always required
        defaults.set(false, forKey: "enableSmartPaste")

        permissionManager.microphonePermissionState = .denied

        XCTAssertFalse(permissionManager.allPermissionsGranted)

        // Clean up
        defaults.removeObject(forKey: "enableSmartPaste")
    }

    // MARK: - SmartPaste Permission Logic Tests

    func testRequestPermissionWithSmartPasteEnabled() {
        defaults.set(true, forKey: "enableSmartPaste")

        permissionManager.microphonePermissionState = .notRequested

        permissionManager.requestPermissionWithEducation()

        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)

        // Clean up
        defaults.removeObject(forKey: "enableSmartPaste")
    }

    func testRequestPermissionWithSmartPasteDisabled() {
        defaults.set(false, forKey: "enableSmartPaste")

        permissionManager.microphonePermissionState = .notRequested

        permissionManager.requestPermissionWithEducation()

        XCTAssertTrue(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)

        // Clean up
        defaults.removeObject(forKey: "enableSmartPaste")
    }

    func testRequestPermissionWithMixedStates() {
        defaults.set(true, forKey: "enableSmartPaste")

        permissionManager.microphonePermissionState = .granted

        permissionManager.requestPermissionWithEducation()

        XCTAssertFalse(permissionManager.showEducationalModal)
        XCTAssertFalse(permissionManager.showRecoveryModal)

        // Clean up
        defaults.removeObject(forKey: "enableSmartPaste")
    }
}
