//
//  QuranDatabaseService.swift
//  QuranApp
//
//  Thread-safe, read-only actor encapsulating SQLite access for the bundled Quran database.
//  Uses native SQLite3 with zero external dependencies for maximum performance and instant compilation.
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public actor QuranDatabaseService: QuranRepositoryProtocol {
    private var db: OpaquePointer?
    private let databasePath: String

    public enum DatabaseError: Error, LocalizedError {
        case fileNotFound(String)
        case connectionFailed(String)
        case queryFailed(String)
        case statementPreparationFailed(String)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "Quran database file not found at: \(path)"
            case .connectionFailed(let message):
                return "Failed to open SQLite database: \(message)"
            case .queryFailed(let message):
                return "Database query execution error: \(message)"
            case .statementPreparationFailed(let message):
                return "Failed to prepare SQLite statement: \(message)"
            }
        }
    }

    public init(databaseURL: URL? = nil) throws {
        let path: String
        if let databaseURL = databaseURL {
            path = databaseURL.path
        } else if let bundlePath = Bundle.main.path(forResource: "quran_content", ofType: "sqlite") {
            path = bundlePath
        } else {
            // Development fallback path
            path = "QuranApp/Resources/Database/quran_content.sqlite"
        }

        self.databasePath = path
        self.db = try Self.open(path: path)
    }

    deinit {
        if let db = db {
            sqlite3_close_v2(db)
        }
    }

    private static func open(path: String) throws -> OpaquePointer {
        var connection: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(path, &connection, flags, nil)
        guard status == SQLITE_OK, let validConnection = connection else {
            let errMsg = connection.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw DatabaseError.connectionFailed(errMsg)
        }
        return validConnection
    }

    // MARK: - Surahs
    public func fetchSurahs() async throws -> [Surah] {
        let sql = """
        SELECT id, arabic_name, english_name, french_name, english_meaning, revelation_type, total_verses, start_page, juz_number
        FROM surahs
        ORDER BY id ASC;
        """
        return try executeQuery(sql: sql) { statement in
            let id = Int(sqlite3_column_int(statement, 0))
            let arabicName = String(cString: sqlite3_column_text(statement, 1))
            let englishName = String(cString: sqlite3_column_text(statement, 2))
            let frenchName = String(cString: sqlite3_column_text(statement, 3))
            let englishMeaning = String(cString: sqlite3_column_text(statement, 4))
            let revTypeRaw = String(cString: sqlite3_column_text(statement, 5))
            let revType = Surah.RevelationType(rawValue: revTypeRaw) ?? .meccan
            let totalVerses = Int(sqlite3_column_int(statement, 6))
            let startPage = Int(sqlite3_column_int(statement, 7))
            let juzNumber = Int(sqlite3_column_int(statement, 8))

            return Surah(
                id: id,
                arabicName: arabicName,
                englishName: englishName,
                frenchName: frenchName,
                englishMeaning: englishMeaning,
                revelationType: revType,
                totalVerses: totalVerses,
                startPage: startPage,
                juzNumber: juzNumber
            )
        }
    }

    public func fetchSurah(id: Int) async throws -> Surah? {
        let sql = """
        SELECT id, arabic_name, english_name, french_name, english_meaning, revelation_type, total_verses, start_page, juz_number
        FROM surahs
        WHERE id = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(id))

        if sqlite3_step(statement) == SQLITE_ROW {
            let sId = Int(sqlite3_column_int(statement, 0))
            let arabicName = String(cString: sqlite3_column_text(statement, 1))
            let englishName = String(cString: sqlite3_column_text(statement, 2))
            let frenchName = String(cString: sqlite3_column_text(statement, 3))
            let englishMeaning = String(cString: sqlite3_column_text(statement, 4))
            let revTypeRaw = String(cString: sqlite3_column_text(statement, 5))
            let revType = Surah.RevelationType(rawValue: revTypeRaw) ?? .meccan
            let totalVerses = Int(sqlite3_column_int(statement, 6))
            let startPage = Int(sqlite3_column_int(statement, 7))
            let juzNumber = Int(sqlite3_column_int(statement, 8))

            return Surah(
                id: sId,
                arabicName: arabicName,
                englishName: englishName,
                frenchName: frenchName,
                englishMeaning: englishMeaning,
                revelationType: revType,
                totalVerses: totalVerses,
                startPage: startPage,
                juzNumber: juzNumber
            )
        }
        return nil
    }

    // MARK: - Juzs
    public func fetchJuzs() async throws -> [Juz] {
        let sql = """
        SELECT id, name_arabic, name_transliteration, start_surah_id, start_verse_number, start_page, first_verse_id, last_verse_id, total_verses
        FROM juzs
        ORDER BY id ASC;
        """
        return try executeQuery(sql: sql) { statement in
            let id = Int(sqlite3_column_int(statement, 0))
            let nameArabic = String(cString: sqlite3_column_text(statement, 1))
            let nameTrans = String(cString: sqlite3_column_text(statement, 2))
            let startSurah = Int(sqlite3_column_int(statement, 3))
            let startVerse = Int(sqlite3_column_int(statement, 4))
            let startPage = Int(sqlite3_column_int(statement, 5))
            let firstVerseId = Int(sqlite3_column_int(statement, 6))
            let lastVerseId = Int(sqlite3_column_int(statement, 7))
            let totalVerses = Int(sqlite3_column_int(statement, 8))

            return Juz(
                id: id,
                nameArabic: nameArabic,
                nameTransliteration: nameTrans,
                startSurahId: startSurah,
                startVerseNumber: startVerse,
                startPage: startPage,
                firstVerseId: firstVerseId,
                lastVerseId: lastVerseId,
                totalVerses: totalVerses
            )
        }
    }

    public func fetchJuz(number: Int) async throws -> Juz? {
        let sql = """
        SELECT id, name_arabic, name_transliteration, start_surah_id, start_verse_number, start_page, first_verse_id, last_verse_id, total_verses
        FROM juzs
        WHERE id = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(number))

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let nameArabic = String(cString: sqlite3_column_text(statement, 1))
            let nameTrans = String(cString: sqlite3_column_text(statement, 2))
            let startSurah = Int(sqlite3_column_int(statement, 3))
            let startVerse = Int(sqlite3_column_int(statement, 4))
            let startPage = Int(sqlite3_column_int(statement, 5))
            let firstVerseId = Int(sqlite3_column_int(statement, 6))
            let lastVerseId = Int(sqlite3_column_int(statement, 7))
            let totalVerses = Int(sqlite3_column_int(statement, 8))

            return Juz(
                id: id,
                nameArabic: nameArabic,
                nameTransliteration: nameTrans,
                startSurahId: startSurah,
                startVerseNumber: startVerse,
                startPage: startPage,
                firstVerseId: firstVerseId,
                lastVerseId: lastVerseId,
                totalVerses: totalVerses
            )
        }
        return nil
    }

    public func fetchSurahJuzSpans() async throws -> [Int: String] {
        let sql = """
        SELECT surah_id, MIN(juz_number) as min_j, MAX(juz_number) as max_j
        FROM ayahs
        GROUP BY surah_id;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var spans: [Int: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            let surahId = Int(sqlite3_column_int(statement, 0))
            let minJ = Int(sqlite3_column_int(statement, 1))
            let maxJ = Int(sqlite3_column_int(statement, 2))

            if minJ == maxJ {
                if minJ == 30 {
                    spans[surahId] = "Juz 30 (Amma)"
                } else {
                    spans[surahId] = "Juz \(minJ)"
                }
            } else {
                spans[surahId] = "Juz \(minJ)–\(maxJ)"
            }
        }
        return spans
    }

    // MARK: - Mushaf Lines (13-Line physical page)
    public func fetchLines(forPage pageNumber: Int) async throws -> [MushafLine] {
        let sql = """
        SELECT id, page_number, line_number, line_type, surah_id, is_centered, text_indopak, words_json
        FROM mushaf_lines
        WHERE page_number = ?
        ORDER BY line_number ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(pageNumber))

        var lines: [MushafLine] = []
        let decoder = JSONDecoder()

        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let page = Int(sqlite3_column_int(statement, 1))
            let lineNum = Int(sqlite3_column_int(statement, 2))
            let lineTypeRaw = String(cString: sqlite3_column_text(statement, 3))
            let lineType = MushafLine.LineType(rawValue: lineTypeRaw) ?? .ayahText
            let surahId = sqlite3_column_type(statement, 4) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 4)) : nil
            let isCentered = sqlite3_column_int(statement, 5) == 1
            let text = sqlite3_column_text(statement, 6).flatMap { String(cString: $0) } ?? ""

            var words: [MushafWord] = []
            if let wordsJsonText = sqlite3_column_text(statement, 7).flatMap({ String(cString: $0) }),
               let data = wordsJsonText.data(using: .utf8) {
                words = (try? decoder.decode([MushafWord].self, from: data)) ?? []
            }

            lines.append(MushafLine(
                id: id,
                pageNumber: page,
                lineNumber: lineNum,
                lineType: lineType,
                surahId: surahId,
                isCentered: isCentered,
                textIndopak: text,
                words: words
            ))
        }
        return lines
    }

    // MARK: - Ayahs
    public func fetchAyahs(forSurah surahId: Int) async throws -> [Ayah] {
        let sql = """
        SELECT id, surah_id, verse_number, page_number, juz_number, hizb_quarter, sajdah, text_indopak, text_clean
        FROM ayahs
        WHERE surah_id = ?
        ORDER BY verse_number ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(surahId))

        var ayahs: [Ayah] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            ayahs.append(parseAyah(from: statement))
        }
        return ayahs
    }

    public func fetchAyah(surah: Int, verse: Int) async throws -> Ayah? {
        let sql = """
        SELECT id, surah_id, verse_number, page_number, juz_number, hizb_quarter, sajdah, text_indopak, text_clean
        FROM ayahs
        WHERE surah_id = ? AND verse_number = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(surah))
        sqlite3_bind_int(statement, 2, Int32(verse))

        if sqlite3_step(statement) == SQLITE_ROW {
            return parseAyah(from: statement)
        }
        return nil
    }

    // MARK: - Translations
    public func fetchTranslation(ayahId: Int, authorCode: Translation.TranslationAuthor) async throws -> Translation? {
        let sql = """
        SELECT id, ayah_id, lang, author_code, text
        FROM translations
        WHERE ayah_id = ? AND author_code = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(ayahId))
        sqlite3_bind_text(statement, 2, authorCode.rawValue, -1, SQLITE_TRANSIENT)

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let aId = Int(sqlite3_column_int(statement, 1))
            let lang = String(cString: sqlite3_column_text(statement, 2))
            let codeRaw = String(cString: sqlite3_column_text(statement, 3))
            let author = Translation.TranslationAuthor(rawValue: codeRaw) ?? authorCode
            let text = String(cString: sqlite3_column_text(statement, 4))

            return Translation(id: id, ayahId: aId, lang: lang, authorCode: author, text: text)
        }
        return nil
    }

    // MARK: - Full-Text Search (FTS5)
    public func search(query: String, limit: Int = 30) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Sanitize query for FTS5 syntax
        let sanitized = trimmed.replacingOccurrences(of: "\"", with: "")
        let ftsQuery = "\"\(sanitized)\"*"

        let sql = """
        SELECT ayah_id, surah_id, verse_number, page_number, arabic_clean, translation_en_saheeh, translation_en_hilali, translation_fr_hamidullah
        FROM search_index
        WHERE search_index MATCH ?
        LIMIT ?;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, ftsQuery, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var results: [SearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let ayahId = Int(sqlite3_column_int(statement, 0))
            let surahId = Int(sqlite3_column_int(statement, 1))
            let verseNum = Int(sqlite3_column_int(statement, 2))
            let pageNum = Int(sqlite3_column_int(statement, 3))
            let arClean = String(cString: sqlite3_column_text(statement, 4))
            let enSaheeh = String(cString: sqlite3_column_text(statement, 5))
            let enHilali = String(cString: sqlite3_column_text(statement, 6))
            let frHamid = String(cString: sqlite3_column_text(statement, 7))

            results.append(SearchResult(
                ayahId: ayahId,
                surahId: surahId,
                verseNumber: verseNum,
                pageNumber: pageNum,
                arabicClean: arClean,
                translationEnSaheeh: enSaheeh,
                translationEnHilali: enHilali,
                translationFrHamidullah: frHamid
            ))
        }
        return results
    }

    // MARK: - Private Helpers
    private func parseAyah(from statement: OpaquePointer?) -> Ayah {
        let id = Int(sqlite3_column_int(statement, 0))
        let surahId = Int(sqlite3_column_int(statement, 1))
        let verseNumber = Int(sqlite3_column_int(statement, 2))
        let pageNumber = Int(sqlite3_column_int(statement, 3))
        let juzNumber = Int(sqlite3_column_int(statement, 4))
        let hizbQuarter = Int(sqlite3_column_int(statement, 5))
        let sajdah = sqlite3_column_int(statement, 6) == 1
        let textIndopak = String(cString: sqlite3_column_text(statement, 7))
        let textClean = String(cString: sqlite3_column_text(statement, 8))

        return Ayah(
            id: id,
            surahId: surahId,
            verseNumber: verseNumber,
            pageNumber: pageNumber,
            juzNumber: juzNumber,
            hizbQuarter: hizbQuarter,
            sajdah: sajdah,
            textIndopak: textIndopak,
            textClean: textClean
        )
    }

    private func executeQuery<T>(sql: String, transform: (OpaquePointer?) -> T) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var results: [T] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(transform(statement))
        }
        return results
    }

    private func lastErrorMessage() -> String {
        guard let db = db else { return "No database connection" }
        return String(cString: sqlite3_errmsg(db))
    }
}
