import Foundation
import SQLite3

/// Keep SwiftData out of the shared Application Support/default.store namespace.
/// Only inspect the legacy database through a read-only SQLite connection: opening
/// an unrelated store with ModelContainer can migrate away its existing schema.
internal enum HistoryStore {
    static func prepareURL(applicationSupport: URL? = nil) throws -> URL {
        let files = FileManager.default
        let support = try applicationSupport ?? files.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        // Stable across display-name changes, like the runtime and preferences.
        let directory = support.appendingPathComponent("AudioWhisper", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("history.store")
        guard !files.fileExists(atPath: destination.path) else { return destination }
        let legacy = support.appendingPathComponent("default.store")
        guard files.fileExists(atPath: legacy.path) else { return destination }

        var source: OpaquePointer?
        guard sqlite3_open_v2(legacy.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            defer { sqlite3_close(source) }
            throw failure(source)
        }
        defer { sqlite3_close(source) }
        sqlite3_busy_timeout(source, 5_000)
        guard sqlite3_exec(source, "BEGIN", nil, nil, nil) == SQLITE_OK else { throw failure(source) }
        defer { sqlite3_exec(source, "ROLLBACK", nil, nil, nil) }
        var query: OpaquePointer?
        guard sqlite3_prepare_v2(source,
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='ZTRANSCRIPTIONRECORD'",
            -1, &query, nil) == SQLITE_OK else { throw failure(source) }
        let result = sqlite3_step(query)
        sqlite3_finalize(query)
        if result == SQLITE_DONE { return destination } // Another app's store: leave untouched.
        guard result == SQLITE_ROW else { throw failure(source) }

        let temporary = directory.appendingPathComponent("history-migration-\(UUID().uuidString).store")
        defer { try? files.removeItem(at: temporary) }
        var copy: OpaquePointer?
        guard sqlite3_open_v2(temporary.path, &copy,
                             SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            defer { sqlite3_close(copy) }
            throw failure(copy)
        }
        do {
            defer { sqlite3_close(copy) }
            guard let backup = sqlite3_backup_init(copy, "main", source, "main") else { throw failure(copy) }
            let copied = sqlite3_backup_step(backup, -1)
            let finished = sqlite3_backup_finish(backup)
            guard copied == SQLITE_DONE, finished == SQLITE_OK else { throw failure(copy) }
        }
        // A coherent SQLite snapshot includes committed WAL entries. Keep that
        // snapshot as a timestamped rollback copy before publishing the new path.
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDirectory = directory.appendingPathComponent(
            "backups/\(stamp)-history-migration-\(UUID().uuidString).noindex", isDirectory: true)
        try files.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try files.copyItem(at: temporary, to: backupDirectory.appendingPathComponent("history.store"))
        try files.moveItem(at: temporary, to: destination)
        return destination
    }

    private static func failure(_ database: OpaquePointer?) -> NSError {
        NSError(domain: "ScribeKitt.HistoryStore", code: Int(sqlite3_errcode(database)),
                userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
    }
}
