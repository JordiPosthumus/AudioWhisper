import XCTest
import SwiftData
import SQLite3
@testable import AudioWhisper

@MainActor
final class HistoryStoreTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("scribekitt-history-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    private func container(_ url: URL) throws -> ModelContainer {
        let schema = Schema([TranscriptionRecord.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
    }

    func testNewInstallationUsesDedicatedStore() throws {
        let root = try temporaryRoot()
        let url = try HistoryStore.prepareURL(applicationSupport: root)
        XCTAssertEqual(url, root.appendingPathComponent("AudioWhisper/history.store"))
        let context = ModelContext(try container(url))
        context.insert(TranscriptionRecord(text: "New private history", provider: .parakeet))
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TranscriptionRecord>()), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("default.store").path))
    }

    func testUnrelatedLegacyStoreRemainsByteIdentical() throws {
        let root = try temporaryRoot()
        let legacy = root.appendingPathComponent("default.store")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(legacy.path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE unrelated(value TEXT); INSERT INTO unrelated VALUES('preserve');", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        let before = try Data(contentsOf: legacy)
        let url = try HistoryStore.prepareURL(applicationSupport: root)
        let context = ModelContext(try container(url))
        context.insert(TranscriptionRecord(text: "Independent record", provider: .parakeet))
        try context.save()
        XCTAssertEqual(try Data(contentsOf: legacy), before)
    }

    func testLegacyMigrationIncludesWALAndPreservesFieldsWithBackup() throws {
        let root = try temporaryRoot()
        let legacy = root.appendingPathComponent("default.store")
        let source = ModelContext(try container(legacy))
        let record = TranscriptionRecord(text: "Keep every field", provider: .parakeet,
            duration: 2.5, modelUsed: "original-model", wordCount: 3, characterCount: 16,
            sourceAppBundleId: "test.app", sourceAppName: "Test", sourceAppIconData: Data([1, 2, 3]))
        source.insert(record)
        try source.save()
        let url = try HistoryStore.prepareURL(applicationSupport: root)
        let target = ModelContext(try container(url))
        let imported = try XCTUnwrap(target.fetch(FetchDescriptor<TranscriptionRecord>()).first)
        XCTAssertEqual(imported.id, record.id)
        XCTAssertEqual(imported.text, record.text)
        XCTAssertEqual(imported.date, record.date)
        XCTAssertEqual(imported.duration, record.duration)
        XCTAssertEqual(imported.modelUsed, record.modelUsed)
        XCTAssertEqual(imported.wordCount, record.wordCount)
        XCTAssertEqual(imported.characterCount, record.characterCount)
        XCTAssertEqual(imported.sourceAppBundleId, record.sourceAppBundleId)
        XCTAssertEqual(imported.sourceAppName, record.sourceAppName)
        XCTAssertEqual(imported.sourceAppIconData, record.sourceAppIconData)
        target.insert(TranscriptionRecord(text: "Only in new store", provider: .parakeet))
        try target.save()
        XCTAssertEqual(try source.fetchCount(FetchDescriptor<TranscriptionRecord>()), 1)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<TranscriptionRecord>()), 2)
        XCTAssertEqual(try HistoryStore.prepareURL(applicationSupport: root), url)
        let backups = try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent().appendingPathComponent("backups"), includingPropertiesForKeys: nil)
        XCTAssertEqual(backups.count, 1)
        let backupContext = ModelContext(try container(backups[0].appendingPathComponent("history.store")))
        XCTAssertEqual(try backupContext.fetch(FetchDescriptor<TranscriptionRecord>()).map(\.id), [record.id])
    }

    func testRecoveredHistoryCanBeReadAndExtendedOnDisposableCopy() throws {
        guard let path = ProcessInfo.processInfo.environment["SCRIBEKITT_RECOVERED_HISTORY"] else {
            throw XCTSkip("Opt-in recovery verification uses a disposable copy")
        }
        let root = try temporaryRoot()
        let copy = root.appendingPathComponent("history.store")
        try FileManager.default.copyItem(atPath: path, toPath: copy.path)
        let context = ModelContext(try container(copy))
        let records = try context.fetch(FetchDescriptor<TranscriptionRecord>())
        XCTAssertEqual(records.count, 213)
        XCTAssertEqual(Set(records.map(\.id)).count, 213)
        // Compare the actual stored text, including any historically empty entry.
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, "SELECT ZTEXT FROM ZTRANSCRIPTIONRECORD", -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var storedText: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            storedText.append(String(cString: sqlite3_column_text(statement, 0)))
        }
        XCTAssertEqual(records.map(\.text).sorted(), storedText.sorted())
        context.insert(TranscriptionRecord(text: "Disposable recovery save check", provider: .parakeet))
        try context.save()
        let reopened = ModelContext(try container(copy))
        XCTAssertEqual(try reopened.fetchCount(FetchDescriptor<TranscriptionRecord>()), 214)
    }
}
