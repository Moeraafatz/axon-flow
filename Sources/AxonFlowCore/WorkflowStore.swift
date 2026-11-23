import Foundation
import SQLite3

private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum WorkflowStoreError: Error, LocalizedError, Sendable {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "SQLite open failed: \(m)"
        case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
        case .executionFailed(let m): return "SQLite exec failed: \(m)"
        }
    }
}

private final class SQLiteHandle: @unchecked Sendable {
    let pointer: OpaquePointer

    init(path: String) throws {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite error"
            if let db { sqlite3_close_v2(db) }
            throw WorkflowStoreError.openFailed(msg)
        }
        guard let opened = db else { throw WorkflowStoreError.openFailed("nil handle") }
        self.pointer = opened
    }

    deinit {
        sqlite3_close_v2(pointer)
    }
}

public actor WorkflowStore {
    public let databaseURL: URL
    private let handle: SQLiteHandle
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public static func defaultDatabaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("AxonFlow", isDirectory: true).appendingPathComponent("workflows.sqlite")
    }

    public init(databaseURL: URL = WorkflowStore.defaultDatabaseURL()) throws {
        self.databaseURL = databaseURL
        try FileManager.default.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        self.handle = try SQLiteHandle(path: databaseURL.path)
        try Self.bootstrap(db: handle.pointer)
    }

    private static func bootstrap(db: OpaquePointer) throws {
        let sql = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;

        CREATE TABLE IF NOT EXISTS workflows (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            updated_at REAL NOT NULL,
            run_count INTEGER NOT NULL DEFAULT 0,
            payload_json BLOB NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_workflows_updated ON workflows(updated_at DESC);
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "schema init failed"
            sqlite3_free(errMsg)
            throw WorkflowStoreError.executionFailed(msg)
        }
    }

    public func upsert(_ workflow: MacroWorkflow) throws {
        let sql = """
        INSERT INTO workflows (id, name, updated_at, run_count, payload_json)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name = excluded.name,
            updated_at = excluded.updated_at,
            run_count = excluded.run_count,
            payload_json = excluded.payload_json;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw WorkflowStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        let payload = try encoder.encode(workflow)
        sqlite3_bind_text(stmt, 1, workflow.id.uuidString, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_text(stmt, 2, workflow.name, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 4, Int64(workflow.runCount))
        _ = payload.withUnsafeBytes { raw in
            sqlite3_bind_blob(stmt, 5, raw.baseAddress, Int32(payload.count), SQLITE_TRANSIENT_DESTRUCTOR)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw WorkflowStoreError.executionFailed(lastError())
        }
    }

    public func fetchAll() throws -> [MacroWorkflow] {
        let sql = "SELECT payload_json FROM workflows ORDER BY updated_at DESC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw WorkflowStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }

        var list: [MacroWorkflow] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let bytes = sqlite3_column_blob(stmt, 0) {
                let len = Int(sqlite3_column_bytes(stmt, 0))
                if let wf = try? decoder.decode(MacroWorkflow.self, from: Data(bytes: bytes, count: len)) {
                    list.append(wf)
                }
            }
        }
        return list
    }

    public func delete(id: UUID) throws {
        let sql = "DELETE FROM workflows WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle.pointer, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw WorkflowStoreError.prepareFailed(lastError())
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw WorkflowStoreError.executionFailed(lastError())
        }
    }

    public func wipeAll() throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle.pointer, "DELETE FROM workflows; VACUUM;", nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "wipe failed"
            sqlite3_free(errMsg)
            throw WorkflowStoreError.executionFailed(msg)
        }
    }

    public func databaseFileSizeBytes() -> Int64 {
        let paths = [databaseURL.path, databaseURL.path + "-wal", databaseURL.path + "-shm"]
        var total: Int64 = 0
        for p in paths {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: p),
               let sz = attrs[.size] as? NSNumber {
                total += sz.int64Value
            }
        }
        return total
    }

    private func lastError() -> String {
        String(cString: sqlite3_errmsg(handle.pointer))
    }
}
