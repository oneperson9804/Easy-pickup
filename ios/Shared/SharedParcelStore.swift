import Foundation
import SQLite3

enum SharedParcelError: LocalizedError {
    case appGroupUnavailable
    case databaseUnavailable
    case databaseOperation
    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable: return "尚未配置共享容器，请使用已配置 App Groups 的签名版本。"
        case .databaseUnavailable: return "请先打开易取件，创建本机取件记录。"
        case .databaseOperation: return "暂时无法读取取件记录，请打开易取件检查。"
        }
    }
}

struct WidgetParcelRecord: Identifiable {
    let id: String
    let station: String
    let code: String
}

struct WidgetParcelSnapshot {
    var count = 0
    var parcels: [WidgetParcelRecord] = []
    var style = "jade"
    var showCodes = true
}

enum SharedParcelStore {
    static let groupIdentifier = "group.io.github.oneperson9804.easypickup"
    static var groupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) != nil
    }

    static func databaseURL(allowFallback: Bool = false) throws -> URL {
        let files = FileManager.default
        if let group = files.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            return group.appendingPathComponent("easy_pickup.db")
        }
        guard allowFallback else { throw SharedParcelError.appGroupUnavailable }
        let support = try files.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try files.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("easy_pickup.db")
    }

    /// Called before Flutter opens the database, to preserve records after App Groups is enabled.
    static func prepareMainDatabase() throws -> URL {
        let destination = try databaseURL(allowFallback: true)
        guard groupAvailable, !FileManager.default.fileExists(atPath: destination.path) else { return destination }
        let files = FileManager.default
        let old = try files.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("easy_pickup.db")
        guard files.fileExists(atPath: old.path) else { return destination }
        var database: OpaquePointer?
        guard sqlite3_open_v2(old.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            throw SharedParcelError.databaseOperation
        }
        let checkpoint = sqlite3_wal_checkpoint_v2(database, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil)
        sqlite3_close(database)
        guard checkpoint == SQLITE_OK else { throw SharedParcelError.databaseOperation }
        try files.copyItem(at: old, to: destination)
        return destination
    }

    private static func withDatabase<T>(writable: Bool = false, operation: (OpaquePointer) throws -> T) throws -> T {
        let path = try databaseURL().path
        guard FileManager.default.fileExists(atPath: path) else { throw SharedParcelError.databaseUnavailable }
        var handle: OpaquePointer?
        let flags = (writable ? SQLITE_OPEN_READWRITE : SQLITE_OPEN_READONLY) | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let database = handle else {
            if let handle { sqlite3_close(handle) }
            throw SharedParcelError.databaseOperation
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 5000)
        return try operation(database)
    }

    static func snapshot() throws -> WidgetParcelSnapshot {
        try withDatabase { database in
            var snapshot = WidgetParcelSnapshot()
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM parcels WHERE deleted_at IS NULL AND collected_at IS NULL", -1, &statement, nil) == SQLITE_OK else { throw SharedParcelError.databaseOperation }
            if sqlite3_step(statement) == SQLITE_ROW { snapshot.count = Int(sqlite3_column_int(statement, 0)) }
            else { sqlite3_finalize(statement); throw SharedParcelError.databaseOperation }
            sqlite3_finalize(statement)
            guard sqlite3_prepare_v2(database, "SELECT id,station,code FROM parcels WHERE deleted_at IS NULL AND collected_at IS NULL ORDER BY arrived_at DESC LIMIT 8", -1, &statement, nil) == SQLITE_OK else { throw SharedParcelError.databaseOperation }
            while sqlite3_step(statement) == SQLITE_ROW {
                snapshot.parcels.append(WidgetParcelRecord(id: text(statement, 0), station: text(statement, 1), code: text(statement, 2)))
            }
            sqlite3_finalize(statement)
            guard sqlite3_prepare_v2(database, "SELECT key,value FROM settings WHERE key IN ('widgetStyle','widgetShowCodes')", -1, &statement, nil) == SQLITE_OK else { throw SharedParcelError.databaseOperation }
            while sqlite3_step(statement) == SQLITE_ROW {
                let key = text(statement, 0)
                let data = Data(text(statement, 1).utf8)
                let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
                if key == "widgetStyle", let style = value as? String { snapshot.style = style }
                if key == "widgetShowCodes", let enabled = value as? Bool { snapshot.showCodes = enabled }
            }
            sqlite3_finalize(statement)
            return snapshot
        }
    }

    static func collect(id: String) throws {
        try withDatabase(writable: true) { database in
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, "UPDATE parcels SET collected_at=? WHERE id=? AND deleted_at IS NULL AND collected_at IS NULL", -1, &statement, nil) == SQLITE_OK else { throw SharedParcelError.databaseOperation }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(Date().timeIntervalSince1970 * 1000))
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 2, id, -1, transient)
            guard sqlite3_step(statement) == SQLITE_DONE else { throw SharedParcelError.databaseOperation }
        }
    }

    private static func text(_ statement: OpaquePointer?, _ column: Int32) -> String {
        guard let value = sqlite3_column_text(statement, column) else { return "" }
        return String(cString: value)
    }
}
