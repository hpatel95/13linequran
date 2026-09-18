//
//  UserDatabaseService.swift
//  QuranApp
//
//  Thread-safe, read-write actor encapsulating SQLite access for user bookmarks,
//  reading logs, and app preferences. Operates in WAL mode with zero third-party dependencies.
//

import Foundation
import SQLite3

public actor UserDatabaseService: UserDatabaseServiceProtocol {
    private var db: OpaquePointer?
    private let databasePath: String
    private let dateFormatter: ISO8601DateFormatter

    public enum DatabaseError: Error, LocalizedError {
        case connectionFailed(String)
        case executionFailed(String)
        case statementPreparationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg):
                return "Failed to open user database: \(msg)"
            case .executionFailed(let msg):
                return "SQLite execution failed: \(msg)"
            case .statementPreparationFailed(let msg):
                return "Failed to prepare SQLite statement: \(msg)"
            }
        }
    }

    public init(databasePath: String? = nil) throws {
        self.dateFormatter = ISO8601DateFormatter()

        if let path = databasePath {
            self.databasePath = path
        } else {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appDir = appSupport.appendingPathComponent("13LineQuran", isDirectory: true)
            if !fileManager.fileExists(atPath: appDir.path) {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            }
            self.databasePath = appDir.appendingPathComponent("user_data.sqlite").path
        }

        var connection: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(self.databasePath, &connection, flags, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(connection))
            sqlite3_close(connection)
            throw DatabaseError.connectionFailed(message)
        }
        self.db = connection

        // Configure WAL mode and pragmas
        sqlite3_exec(db, "PRAGMA journal_mode = WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys = ON;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous = NORMAL;", nil, nil, nil)

        // Initialize schema
        try createSchema()
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    // MARK: - Schema Initialization
    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ayah_id INTEGER,
            surah_id INTEGER,
            verse_number INTEGER,
            page_number INTEGER NOT NULL,
            title TEXT NOT NULL,
            arabic_snippet TEXT,
            translation_snippet TEXT,
            note TEXT,
            created_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_bookmarks_ayah ON bookmarks(ayah_id);
        CREATE INDEX IF NOT EXISTS idx_bookmarks_page ON bookmarks(page_number);

        CREATE TABLE IF NOT EXISTS reading_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            page_number INTEGER NOT NULL,
            start_time TEXT NOT NULL,
            duration_seconds REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_reading_sessions_page ON reading_sessions(page_number);

        CREATE TABLE IF NOT EXISTS app_preferences (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
            sqlite3_free(errMsg)
            throw DatabaseError.executionFailed(msg)
        }
    }

    // MARK: - Bookmarks Methods
    public func fetchBookmarks() async throws -> [Bookmark] {
        let sql = """
        SELECT id, ayah_id, surah_id, verse_number, page_number, title, arabic_snippet, translation_snippet, note, created_at
        FROM bookmarks
        ORDER BY id DESC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var results: [Bookmark] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let ayahId: Int? = sqlite3_column_type(statement, 1) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 1))
            let surahId: Int? = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 2))
            let verseNum: Int? = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 3))
            let pageNum = Int(sqlite3_column_int(statement, 4))
            let title = String(cString: sqlite3_column_text(statement, 5))

            let arabicSnippet: String? = sqlite3_column_type(statement, 6) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(statement, 6))
            let transSnippet: String? = sqlite3_column_type(statement, 7) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(statement, 7))
            let note: String? = sqlite3_column_type(statement, 8) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(statement, 8))
            let dateStr = String(cString: sqlite3_column_text(statement, 9))
            let createdAt = dateFormatter.date(from: dateStr) ?? Date()

            results.append(Bookmark(
                id: id,
                ayahId: ayahId,
                surahId: surahId,
                verseNumber: verseNum,
                pageNumber: pageNum,
                title: title,
                arabicSnippet: arabicSnippet,
                translationSnippet: transSnippet,
                note: note,
                createdAt: createdAt
            ))
        }
        return results
    }

    public func isAyahBookmarked(ayahId: Int) async throws -> Bool {
        let sql = "SELECT 1 FROM bookmarks WHERE ayah_id = ? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(ayahId))
        return sqlite3_step(statement) == SQLITE_ROW
    }

    public func isPageBookmarked(pageNumber: Int) async throws -> Bool {
        let sql = "SELECT 1 FROM bookmarks WHERE page_number = ? AND ayah_id IS NULL LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(pageNumber))
        return sqlite3_step(statement) == SQLITE_ROW
    }

    public func fetchBookmarkedAyahIds() async throws -> Set<Int> {
        let sql = "SELECT ayah_id FROM bookmarks WHERE ayah_id IS NOT NULL;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var ids = Set<Int>()
        while sqlite3_step(statement) == SQLITE_ROW {
            let ayahId = Int(sqlite3_column_int(statement, 0))
            ids.insert(ayahId)
        }
        return ids
    }

    public func addAyahBookmark(
        ayahId: Int,
        surahId: Int,
        verseNumber: Int,
        pageNumber: Int,
        title: String,
        arabic: String,
        translation: String,
        note: String?
    ) async throws -> Bookmark {
        // Prevent duplicates
        if try await isAyahBookmarked(ayahId: ayahId) {
            let all = try await fetchBookmarks()
            if let existing = all.first(where: { $0.ayahId == ayahId }) {
                return existing
            }
        }

        let sql = """
        INSERT INTO bookmarks (ayah_id, surah_id, verse_number, page_number, title, arabic_snippet, translation_snippet, note, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let now = Date()
        let nowStr = dateFormatter.string(from: now)

        sqlite3_bind_int(statement, 1, Int32(ayahId))
        sqlite3_bind_int(statement, 2, Int32(surahId))
        sqlite3_bind_int(statement, 3, Int32(verseNumber))
        sqlite3_bind_int(statement, 4, Int32(pageNumber))
        sqlite3_bind_text(statement, 5, (title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 6, (arabic as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 7, (translation as NSString).utf8String, -1, nil)
        if let note = note {
            sqlite3_bind_text(statement, 8, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        sqlite3_bind_text(statement, 9, (nowStr as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }

        let newId = Int(sqlite3_last_insert_rowid(db))
        return Bookmark(
            id: newId,
            ayahId: ayahId,
            surahId: surahId,
            verseNumber: verseNumber,
            pageNumber: pageNumber,
            title: title,
            arabicSnippet: arabic,
            translationSnippet: translation,
            note: note,
            createdAt: now
        )
    }

    public func addPageBookmark(pageNumber: Int, title: String, note: String?) async throws -> Bookmark {
        if try await isPageBookmarked(pageNumber: pageNumber) {
            let all = try await fetchBookmarks()
            if let existing = all.first(where: { $0.pageNumber == pageNumber && $0.ayahId == nil }) {
                return existing
            }
        }

        let sql = """
        INSERT INTO bookmarks (ayah_id, surah_id, verse_number, page_number, title, arabic_snippet, translation_snippet, note, created_at)
        VALUES (NULL, NULL, NULL, ?, ?, NULL, NULL, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let now = Date()
        let nowStr = dateFormatter.string(from: now)

        sqlite3_bind_int(statement, 1, Int32(pageNumber))
        sqlite3_bind_text(statement, 2, (title as NSString).utf8String, -1, nil)
        if let note = note {
            sqlite3_bind_text(statement, 3, (note as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_text(statement, 4, (nowStr as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }

        let newId = Int(sqlite3_last_insert_rowid(db))
        return Bookmark(
            id: newId,
            ayahId: nil,
            surahId: nil,
            verseNumber: nil,
            pageNumber: pageNumber,
            title: title,
            arabicSnippet: nil,
            translationSnippet: nil,
            note: note,
            createdAt: now
        )
    }

    public func removeBookmark(id: Int) async throws {
        let sql = "DELETE FROM bookmarks WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(id))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }
    }

    public func removeAyahBookmark(ayahId: Int) async throws {
        let sql = "DELETE FROM bookmarks WHERE ayah_id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(ayahId))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }
    }

    public func removePageBookmark(pageNumber: Int) async throws {
        let sql = "DELETE FROM bookmarks WHERE page_number = ? AND ayah_id IS NULL;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(pageNumber))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }
    }

    // MARK: - Last Read & Preferences
    public func saveLastReadPage(_ pageNumber: Int) async throws {
        try await setPreference(key: "last_read_page", value: String(pageNumber))
    }

    public func getLastReadPage() async throws -> Int {
        if let val = try await getPreference(key: "last_read_page"), let page = Int(val), page >= 1 && page <= 849 {
            return page
        }
        return 1
    }

    public func setPreference(key: String, value: String) async throws {
        let sql = """
        INSERT INTO app_preferences (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (value as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }
    }

    public func getPreference(key: String) async throws -> String? {
        let sql = "SELECT value FROM app_preferences WHERE key = ? LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (key as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(statement, 0))
        }
        return nil
    }

    // MARK: - Reading Sessions
    public func recordReadingSession(pageNumber: Int, durationSeconds: Double) async throws {
        let sql = """
        INSERT INTO reading_sessions (page_number, start_time, duration_seconds)
        VALUES (?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let nowStr = dateFormatter.string(from: Date())
        sqlite3_bind_int(statement, 1, Int32(pageNumber))
        sqlite3_bind_text(statement, 2, (nowStr as NSString).utf8String, -1, nil)
        sqlite3_bind_double(statement, 3, durationSeconds)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.executionFailed(lastErrorMessage())
        }
    }

    public func fetchRecentPages(limit: Int = 10) async throws -> [Int] {
        let sql = """
        SELECT DISTINCT page_number
        FROM reading_sessions
        ORDER BY id DESC
        LIMIT ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))

        var pages: [Int] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            pages.append(Int(sqlite3_column_int(statement, 0)))
        }
        return pages
    }

    // MARK: - Helper
    private func lastErrorMessage() -> String {
        guard let db = db else { return "Database not opened" }
        return String(cString: sqlite3_errmsg(db))
    }
}
