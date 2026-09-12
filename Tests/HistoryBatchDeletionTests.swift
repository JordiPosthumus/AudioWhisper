import XCTest
import SwiftData
@testable import AudioWhisper

@MainActor
final class HistoryBatchDeletionTests: XCTestCase {
    func testBatchDeletionPersistsOnlySelectedIDsAndRebuildsMetrics() async throws {
        let container = try ModelContainer(for: TranscriptionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let records = (0..<100).map { TranscriptionRecord(text: "record \($0)", provider: .local, wordCount: 2) }
        for record in records { context.insert(record) }
        try context.save()
        let manager: DataManagerProtocol = DataManager(modelContainer: container)
        let selection = Array(records.prefix(80))
        // Duplicate IDs and stale selections should not cause repeated deletes or corrupt counts.
        try await manager.deleteRecords(selection + [records[0], TranscriptionRecord(text: "absent", provider: .local)])
        let remaining = try await manager.fetchAllRecords()
        XCTAssertEqual(Set(remaining.map(\.id)), Set(records.suffix(20).map(\.id)))
        XCTAssertEqual(UsageMetricsStore.shared.snapshot.totalSessions, 20)
        XCTAssertEqual(UsageMetricsStore.shared.snapshot.totalWords, 40)
        try await manager.deleteRecords([])
        let unchanged = try await manager.fetchAllRecords()
        XCTAssertEqual(unchanged.count, 20)
    }

    func testMockPaginationPastEndIsEmpty() async throws {
        let manager = MockDataManager()
        try await manager.saveTranscription(TranscriptionRecord(text: "hello", provider: .local))
        for offset in [1, 100] {
            let page = try await manager.fetchRecords(matching: "", limit: 10, offset: offset)
            XCTAssertTrue(page.isEmpty)
        }
    }
}
