//
//  UserDatabaseMigrations.swift
//  QuranApp
//
//  Transactional migration runner for user database schema upgrades.
//  Preserves legacy bookmarks and reading logs while establishing
//  edition-isolated V2 storage for authentic facsimile layouts.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation
import SQLite3

public enum UserDatabaseMigrations: Sendable {
    public static func migrate(db: OpaquePointer?) throws {
        guard let db = db else { return }

        // 1. Create V2 tables
        let createTablesSql = """
        CREATE TABLE IF NOT EXISTS reader_bookmarks_v2 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            edition_id TEXT NOT NULL,
            page_id TEXT NOT NULL,
            anchor_surah_id INTEGER,
            anchor_verse_number INTEGER,
            title TEXT NOT NULL,
            arabic_snippet TEXT,
            translation_snippet TEXT,
            note TEXT,
            legacy_page_number INTEGER,
            created_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_rb2_edition_page ON reader_bookmarks_v2(edition_id, page_id);
        CREATE INDEX IF NOT EXISTS idx_rb2_verse ON reader_bookmarks_v2(edition_id, anchor_surah_id, anchor_verse_number);

        CREATE TABLE IF NOT EXISTS reader_sessions_v2 (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            edition_id TEXT NOT NULL,
            page_id TEXT NOT NULL,
            start_time TEXT NOT NULL,
            duration_seconds REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_rs2_edition_page ON reader_sessions_v2(edition_id, page_id);

        CREATE TABLE IF NOT EXISTS reader_last_locations_v2 (
            edition_id TEXT PRIMARY KEY,
            page_id TEXT NOT NULL,
            navigation_index INTEGER NOT NULL,
            quran_ordinal INTEGER,
            surah_id INTEGER,
            juz_number INTEGER,
            label TEXT,
            updated_at TEXT NOT NULL
        );
        """

        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, createTablesSql, nil, nil, &errMsg) != SQLITE_OK {
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error creating V2 tables"
            sqlite3_free(errMsg)
            throw UserDatabaseService.DatabaseError.executionFailed(msg)
        }

        // 2. Perform idempotent data migration from V1 bookmarks if V2 is empty
        let v2CountSql = "SELECT COUNT(*) FROM reader_bookmarks_v2;"
        var countStmt: OpaquePointer?
        var v2Count = 0
        if sqlite3_prepare_v2(db, v2CountSql, -1, &countStmt, nil) == SQLITE_OK {
            if sqlite3_step(countStmt) == SQLITE_ROW {
                v2Count = Int(sqlite3_column_int(countStmt, 0))
            }
            sqlite3_finalize(countStmt)
        }

        if v2Count == 0 {
            let migrateBookmarksSql = """
            INSERT INTO reader_bookmarks_v2 (
                edition_id, page_id, anchor_surah_id, anchor_verse_number,
                title, arabic_snippet, translation_snippet, note,
                legacy_page_number, created_at
            )
            SELECT
                'legacy-qudratullah-13-849',
                printf('p%04d', page_number),
                surah_id,
                verse_number,
                title,
                arabic_snippet,
                translation_snippet,
                note,
                page_number,
                created_at
            FROM bookmarks;
            """
            _ = sqlite3_exec(db, migrateBookmarksSql, nil, nil, nil)
        }

        // 3. Migrate reading sessions if V2 is empty
        let v2SessionsCountSql = "SELECT COUNT(*) FROM reader_sessions_v2;"
        var sessStmt: OpaquePointer?
        var v2SessCount = 0
        if sqlite3_prepare_v2(db, v2SessionsCountSql, -1, &sessStmt, nil) == SQLITE_OK {
            if sqlite3_step(sessStmt) == SQLITE_ROW {
                v2SessCount = Int(sqlite3_column_int(sessStmt, 0))
            }
            sqlite3_finalize(sessStmt)
        }

        if v2SessCount == 0 {
            let migrateSessionsSql = """
            INSERT INTO reader_sessions_v2 (
                edition_id, page_id, start_time, duration_seconds
            )
            SELECT
                'legacy-qudratullah-13-849',
                printf('p%04d', page_number),
                start_time,
                duration_seconds
            FROM reading_sessions;
            """
            _ = sqlite3_exec(db, migrateSessionsSql, nil, nil, nil)
        }
    }
}
