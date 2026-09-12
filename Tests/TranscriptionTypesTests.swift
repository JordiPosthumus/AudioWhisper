import XCTest
import Foundation
@testable import AudioWhisper

class TranscriptionTypesTests: XCTestCase {
    
    // MARK: - TranscriptionProvider Tests
    
    func testTranscriptionProviderCases() {
        let allCases = TranscriptionProvider.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.openai))
        XCTAssertTrue(allCases.contains(.gemini))
        XCTAssertTrue(allCases.contains(.local))
        XCTAssertTrue(allCases.contains(.parakeet))
    }
    
    func testTranscriptionProviderDisplayNames() {
        XCTAssertEqual(TranscriptionProvider.openai.displayName, "OpenAI Whisper (Cloud)")
        XCTAssertEqual(TranscriptionProvider.gemini.displayName, "Google Gemini (Cloud)")
        XCTAssertEqual(TranscriptionProvider.local.displayName, "Whisper (Local)")
        XCTAssertEqual(TranscriptionProvider.parakeet.displayName, "Parakeet")
    }
    
    func testTranscriptionProviderRawValues() {
        XCTAssertEqual(TranscriptionProvider.openai.rawValue, "openai")
        XCTAssertEqual(TranscriptionProvider.gemini.rawValue, "gemini")
        XCTAssertEqual(TranscriptionProvider.local.rawValue, "local")
        XCTAssertEqual(TranscriptionProvider.parakeet.rawValue, "parakeet")
    }
    
    func testTranscriptionProviderFromRawValue() {
        XCTAssertEqual(TranscriptionProvider(rawValue: "openai"), .openai)
        XCTAssertEqual(TranscriptionProvider(rawValue: "gemini"), .gemini)
        XCTAssertEqual(TranscriptionProvider(rawValue: "local"), .local)
        XCTAssertEqual(TranscriptionProvider(rawValue: "parakeet"), .parakeet)
        XCTAssertNil(TranscriptionProvider(rawValue: "invalid"))
    }
    
    func testTranscriptionProviderCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test encoding
        let openaiData = try encoder.encode(TranscriptionProvider.openai)
        let geminiData = try encoder.encode(TranscriptionProvider.gemini)
        let localData = try encoder.encode(TranscriptionProvider.local)
        let parakeetData = try encoder.encode(TranscriptionProvider.parakeet)
        
        // Test decoding
        let decodedOpenai = try decoder.decode(TranscriptionProvider.self, from: openaiData)
        let decodedGemini = try decoder.decode(TranscriptionProvider.self, from: geminiData)
        let decodedLocal = try decoder.decode(TranscriptionProvider.self, from: localData)
        let decodedParakeet = try decoder.decode(TranscriptionProvider.self, from: parakeetData)
        
        XCTAssertEqual(decodedOpenai, .openai)
        XCTAssertEqual(decodedGemini, .gemini)
        XCTAssertEqual(decodedLocal, .local)
        XCTAssertEqual(decodedParakeet, .parakeet)
    }
    
    func testOnlyParakeetV2ModelIsSupported() throws {
        XCTAssertEqual(ParakeetModel.v2English.rawValue, "mlx-community/parakeet-tdt-0.6b-v2")
        XCTAssertNil(ParakeetModel(rawValue: "mlx-community/parakeet-tdt-0.6b-v3"))
        let data = try JSONEncoder().encode(ParakeetModel.v2English)
        XCTAssertEqual(try JSONDecoder().decode(ParakeetModel.self, from: data), .v2English)
    }
}
