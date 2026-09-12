import XCTest
@testable import AudioWhisper

@MainActor
final class SoundManagerTests: XCTestCase {
    
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var soundProvider: MockSoundProvider!
    private var soundManager: SoundManager!
    
    override func setUp() {
        super.setUp()
        suiteName = "SoundManagerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        soundProvider = MockSoundProvider()
        soundManager = SoundManager(soundProvider: soundProvider, defaults: defaults)
        defaults.removeObject(forKey: "playCompletionSound")
    }
    
    override func tearDown() {
        defaults.removeObject(forKey: "playCompletionSound")
        defaults.removePersistentDomain(forName: suiteName)
        soundManager = nil
        soundProvider = nil
        super.tearDown()
    }
    
    func testPlayCompletionSound_DefaultPreferencePlaysGlass() {
        soundManager.playCompletionSound()
        
        XCTAssertEqual(soundProvider.requestedNames, ["Glass"])
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 1)
    }
    
    func testPlayCompletionSound_WhenDisabledDoesNotPlay() {
        defaults.set(false, forKey: "playCompletionSound")
        
        soundManager.playCompletionSound()
        
        XCTAssertTrue(soundProvider.requestedNames.isEmpty)
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 0)
    }
    
    func testPlayCompletionSound_WhenEnabledPlaysOnce() {
        defaults.set(true, forKey: "playCompletionSound")
        
        soundManager.playCompletionSound()
        
        XCTAssertEqual(soundProvider.requestedNames, ["Glass"])
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 1)
    }
    
    func testPlayRecordingStartSound_UsesPingSound() {
        soundManager.playRecordingStartSound()
        
        XCTAssertEqual(soundProvider.requestedNames, ["Ping"])
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 1)
    }
    
    func testPlayRecordingStartSound_WhenDisabledDoesNotPlay() {
        defaults.set(false, forKey: "playCompletionSound")
        
        soundManager.playRecordingStartSound()
        
        XCTAssertTrue(soundProvider.requestedNames.isEmpty)
        XCTAssertEqual(soundProvider.defaultSound.playCallCount, 0)
    }
}
