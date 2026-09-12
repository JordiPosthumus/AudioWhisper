import XCTest
import SwiftUI
import SwiftData
@testable import AudioWhisper

@MainActor
final class UISnapshotTests: SnapshotTestCase {
    func testTranscriptionHistoryViewSnapshot() throws {
        let container = try makePreviewContainer()
        let view = TranscriptionHistoryView()
            .modelContainer(container)
        
        assertSnapshot(
            view,
            named: "TranscriptionHistoryView-dark",
            size: LayoutMetrics.TranscriptionHistory.previewSize,
            colorScheme: .dark
        )
    }
}

// MARK: - Helpers
private extension UISnapshotTests {
    func makePreviewContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        
        let sampleRecords = [
            TranscriptionRecord(
                text: "This is a sample transcription from OpenAI Whisper service. It demonstrates how the history view will look with longer text content.",
                provider: .openai,
                duration: 12.5,
                modelUsed: "large-v3"
            ),
            TranscriptionRecord(
                text: "Meeting notes about upcoming launch. Includes key dates and action items.",
                provider: .gemini,
                duration: 8.3,
                modelUsed: "gemini-pro"
            ),
            TranscriptionRecord(
                text: "Quick local test recording to verify offline pipeline works correctly.",
                provider: .local,
                duration: 4.2,
                modelUsed: "base"
            )
        ]
        
        for record in sampleRecords {
            context.insert(record)
        }
        try context.save()
        return container
    }
}
