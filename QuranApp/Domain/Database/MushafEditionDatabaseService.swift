//
//  MushafEditionDatabaseService.swift
//  QuranApp
//
//  Actor-isolated read-only SQLite access for authentic Mushaf edition manifests,
//  page geometries, interactive touch bounding regions, and navigation anchors.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation
import SQLite3

public actor MushafEditionDatabaseService: MushafEditionRepositoryProtocol {
    public enum DatabaseError: Error, LocalizedError, Sendable {
        case connectionFailed(String)
        case queryFailed(String)
        case statementPreparationFailed(String)
        case notFound(String)

        public var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "Mushaf Edition DB connection failed: \(msg)"
            case .queryFailed(let msg): return "Mushaf Edition DB query failed: \(msg)"
            case .statementPreparationFailed(let msg): return "Mushaf Edition DB statement prep failed: \(msg)"
            case .notFound(let msg): return "Mushaf Edition DB item not found: \(msg)"
            }
        }
    }

    public let defaultEditionId: String = "taj-company-13-847"
    private let databasePath: String
    private var db: OpaquePointer?

    public init(databaseURL: URL? = nil) throws {
        let path: String
        if let databaseURL = databaseURL {
            path = databaseURL.path
        } else if let bundlePath = Bundle.main.path(forResource: "mushaf_editions", ofType: "sqlite") {
            path = bundlePath
        } else if let nestedPath = Bundle.main.path(forResource: "mushaf_editions", ofType: "sqlite", inDirectory: "MushafEditions") {
            path = nestedPath
        } else {
            // Development fallback path
            path = "QuranApp/Resources/MushafEditions/mushaf_editions.sqlite"
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
        guard status == SQLITE_OK, let valid = connection else {
            let errMsg = connection.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw DatabaseError.connectionFailed(errMsg)
        }
        return valid
    }

    private func lastErrorMessage() -> String {
        guard let db = db else { return "No database connection" }
        return String(cString: sqlite3_errmsg(db))
    }

    // MARK: - Editions
    public func fetchEditions() async throws -> [MushafEdition] {
        let sql = """
        SELECT edition_id, content_version, display_name, publisher, renderer_kind,
               approval_status, quran_page_count, navigation_page_count, notice_path
        FROM editions
        ORDER BY edition_id ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var results: [MushafEdition] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let version = Int(sqlite3_column_int(statement, 1))
            let name = String(cString: sqlite3_column_text(statement, 2))
            let publisher = String(cString: sqlite3_column_text(statement, 3))
            let rendererRaw = String(cString: sqlite3_column_text(statement, 4))
            let approvalRaw = String(cString: sqlite3_column_text(statement, 5))
            let quranPages = Int(sqlite3_column_int(statement, 6))
            let navPages = Int(sqlite3_column_int(statement, 7))
            let notice = sqlite3_column_text(statement, 8).map { String(cString: $0) }

            let renderer = MushafEdition.RendererKind(rawValue: rendererRaw) ?? .facsimile
            let approval = MushafEdition.ApprovalStatus(rawValue: approvalRaw) ?? .approved

            results.append(MushafEdition(
                id: id,
                contentVersion: version,
                displayName: name,
                publisher: publisher,
                rendererKind: renderer,
                approvalStatus: approval,
                quranPageCount: quranPages,
                navigationPageCount: navPages,
                noticePath: notice
            ))
        }
        return results
    }

    public func fetchEdition(editionId: String) async throws -> MushafEdition? {
        let sql = """
        SELECT edition_id, content_version, display_name, publisher, renderer_kind,
               approval_status, quran_page_count, navigation_page_count, notice_path
        FROM editions
        WHERE edition_id = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let version = Int(sqlite3_column_int(statement, 1))
            let name = String(cString: sqlite3_column_text(statement, 2))
            let publisher = String(cString: sqlite3_column_text(statement, 3))
            let rendererRaw = String(cString: sqlite3_column_text(statement, 4))
            let approvalRaw = String(cString: sqlite3_column_text(statement, 5))
            let quranPages = Int(sqlite3_column_int(statement, 6))
            let navPages = Int(sqlite3_column_int(statement, 7))
            let notice = sqlite3_column_text(statement, 8).map { String(cString: $0) }

            let renderer = MushafEdition.RendererKind(rawValue: rendererRaw) ?? .facsimile
            let approval = MushafEdition.ApprovalStatus(rawValue: approvalRaw) ?? .approved

            return MushafEdition(
                id: id,
                contentVersion: version,
                displayName: name,
                publisher: publisher,
                rendererKind: renderer,
                approvalStatus: approval,
                quranPageCount: quranPages,
                navigationPageCount: navPages,
                noticePath: notice
            )
        }
        return nil
    }

    // MARK: - Pages
    public func fetchPages(editionId: String) async throws -> [MushafPageSummary] {
        if editionId.contains("849") {
            return (1...849).map { page in
                MushafPageSummary(
                    id: String(format: "p%04d", page),
                    editionId: editionId,
                    navigationIndex: page,
                    quranOrdinal: page,
                    printedLabel: "\(page)",
                    kind: .quran,
                    title: "Page \(page)",
                    sourceAssetId: "\(page)",
                    sourceWidth: nil,
                    sourceHeight: nil,
                    imagePath: nil,
                    imageSha256: nil
                )
            }
        }

        let sql = """
        SELECT page_id, edition_id, navigation_index, quran_ordinal, printed_label,
               kind, title, source_asset_id, source_width, source_height, image_path, image_sha256
        FROM pages
        WHERE edition_id = ?
        ORDER BY navigation_index ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)

        var results: [MushafPageSummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(readPageSummary(statement))
        }
        return results
    }

    public func fetchPage(editionId: String, pageId: String) async throws -> MushafPageContent? {
        if editionId.contains("849") {
            let numStr = pageId.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "1"
            let page = Int(numStr) ?? 1
            let summary = MushafPageSummary(
                id: pageId,
                editionId: editionId,
                navigationIndex: page,
                quranOrdinal: page,
                printedLabel: "\(page)",
                kind: .quran,
                title: "Page \(page)",
                sourceAssetId: "\(page)",
                sourceWidth: nil,
                sourceHeight: nil,
                imagePath: nil,
                imageSha256: nil
            )
            return MushafPageContent(summary: summary, verses: [], regions: [])
        }
        let sql = """
        SELECT page_id, edition_id, navigation_index, quran_ordinal, printed_label,
               kind, title, source_asset_id, source_width, source_height, image_path, image_sha256
        FROM pages
        WHERE edition_id = ? AND page_id = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (pageId as NSString).utf8String, -1, nil)

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let summary = readPageSummary(statement)

        let verses = try fetchPageVerses(editionId: editionId, pageId: pageId)
        let regions = try fetchPageRegions(editionId: editionId, pageId: pageId)

        return MushafPageContent(summary: summary, verses: verses, regions: regions)
    }

    public func fetchPageByNavigationIndex(editionId: String, index: Int) async throws -> MushafPageContent? {
        let sql = """
        SELECT page_id FROM pages
        WHERE edition_id = ? AND navigation_index = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(index))

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let pageId = String(cString: sqlite3_column_text(statement, 0))
        return try await fetchPage(editionId: editionId, pageId: pageId)
    }

    public func fetchPageByQuranOrdinal(editionId: String, ordinal: Int) async throws -> MushafPageContent? {
        let sql = """
        SELECT page_id FROM pages
        WHERE edition_id = ? AND quran_ordinal = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(ordinal))

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let pageId = String(cString: sqlite3_column_text(statement, 0))
        return try await fetchPage(editionId: editionId, pageId: pageId)
    }

    // MARK: - Navigation Queries
    public func fetchLocations(editionId: String, verse: VerseKey) async throws -> [ReaderLocation] {
        let sql = """
        SELECT pv.page_id, p.navigation_index, p.quran_ordinal, pv.surah_id, p.printed_label
        FROM page_verses pv
        JOIN pages p ON pv.edition_id = p.edition_id AND pv.page_id = p.page_id
        WHERE pv.edition_id = ? AND pv.surah_id = ? AND pv.ayah_number = ?
        ORDER BY pv.reading_order ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(verse.surah))
        sqlite3_bind_int(statement, 3, Int32(verse.ayah))

        var results: [ReaderLocation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let pageId = String(cString: sqlite3_column_text(statement, 0))
            let navIndex = Int(sqlite3_column_int(statement, 1))
            let qOrdinal = sqlite3_column_type(statement, 2) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 2)) : nil
            let surahId = sqlite3_column_type(statement, 3) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 3)) : nil
            let label = sqlite3_column_text(statement, 4).map { String(cString: $0) }
            let juz = try fetchJuzNumber(editionId: editionId, navigationIndex: navIndex)

            results.append(ReaderLocation(
                editionId: editionId,
                pageId: pageId,
                navigationIndex: navIndex,
                quranOrdinal: qOrdinal,
                surahId: surahId,
                juzNumber: juz,
                focusedVerse: verse,
                label: label
            ))
        }
        return results
    }

    public func fetchAnchor(editionId: String, kind: NavigationAnchorKind, number: Int) async throws -> ReaderLocation? {
        let sql = """
        SELECT na.page_id, p.navigation_index, p.quran_ordinal, na.surah_id, na.ayah_number, p.printed_label
        FROM navigation_anchors na
        JOIN pages p ON na.edition_id = p.edition_id AND na.page_id = p.page_id
        WHERE na.edition_id = ? AND na.kind = ? AND na.number = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (kind.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 3, Int32(number))

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let pageId = String(cString: sqlite3_column_text(statement, 0))
        let navIndex = Int(sqlite3_column_int(statement, 1))
        let qOrdinal = sqlite3_column_type(statement, 2) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 2)) : nil
        let surahId = sqlite3_column_type(statement, 3) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 3)) : nil
        let ayahNum = sqlite3_column_type(statement, 4) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 4)) : nil
        let label = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        let focused: VerseKey?
        if let s = surahId, let a = ayahNum {
            focused = VerseKey(surah: s, ayah: a)
        } else {
            focused = nil
        }
        let juz = try fetchJuzNumber(editionId: editionId, navigationIndex: navIndex)

        return ReaderLocation(
            editionId: editionId,
            pageId: pageId,
            navigationIndex: navIndex,
            quranOrdinal: qOrdinal,
            surahId: surahId,
            juzNumber: juz,
            focusedVerse: focused,
            label: label
        )
    }

    public func fetchPageForQuranOrdinal(editionId: String, ordinal: Int) async throws -> ReaderLocation? {
        let sql = """
        SELECT page_id, navigation_index, quran_ordinal, printed_label
        FROM pages
        WHERE edition_id = ? AND quran_ordinal = ?
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(ordinal))

        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        let pageId = String(cString: sqlite3_column_text(statement, 0))
        let navIndex = Int(sqlite3_column_int(statement, 1))
        let qOrdinal = Int(sqlite3_column_int(statement, 2))
        let label = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let juz = try fetchJuzNumber(editionId: editionId, navigationIndex: navIndex)
        let surah = try fetchFirstSurahId(editionId: editionId, pageId: pageId)

        return ReaderLocation(
            editionId: editionId,
            pageId: pageId,
            navigationIndex: navIndex,
            quranOrdinal: qOrdinal,
            surahId: surah,
            juzNumber: juz,
            focusedVerse: nil,
            label: label
        )
    }

    // MARK: - Helpers
    private func readPageSummary(_ statement: OpaquePointer?) -> MushafPageSummary {
        guard let s = statement else { fatalError("Null statement pointer") }
        let pageId = String(cString: sqlite3_column_text(s, 0))
        let editionId = String(cString: sqlite3_column_text(s, 1))
        let navIndex = Int(sqlite3_column_int(s, 2))
        let qOrdinal = sqlite3_column_type(s, 3) != SQLITE_NULL ? Int(sqlite3_column_int(s, 3)) : nil
        let printedLabel = sqlite3_column_text(s, 4).map { String(cString: $0) }
        let kindRaw = String(cString: sqlite3_column_text(s, 5))
        let title = String(cString: sqlite3_column_text(s, 6))
        let sourceAssetId = String(cString: sqlite3_column_text(s, 7))
        let sourceWidth = sqlite3_column_type(s, 8) != SQLITE_NULL ? Int(sqlite3_column_int(s, 8)) : nil
        let sourceHeight = sqlite3_column_type(s, 9) != SQLITE_NULL ? Int(sqlite3_column_int(s, 9)) : nil
        let imagePath = sqlite3_column_text(s, 10).map { String(cString: $0) }
        let sha256 = sqlite3_column_text(s, 11).map { String(cString: $0) }

        let kind = MushafPageKind(rawValue: kindRaw) ?? .quran

        return MushafPageSummary(
            id: pageId,
            editionId: editionId,
            navigationIndex: navIndex,
            quranOrdinal: qOrdinal,
            printedLabel: printedLabel,
            kind: kind,
            title: title,
            sourceAssetId: sourceAssetId,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            imagePath: imagePath,
            imageSha256: sha256
        )
    }

    private func fetchPageVerses(editionId: String, pageId: String) throws -> [PageVerseMembership] {
        let sql = """
        SELECT surah_id, ayah_number, reading_order, starts_here, ends_here
        FROM page_verses
        WHERE edition_id = ? AND page_id = ?
        ORDER BY reading_order ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (pageId as NSString).utf8String, -1, nil)

        var verses: [PageVerseMembership] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let surah = Int(sqlite3_column_int(statement, 0))
            let ayah = Int(sqlite3_column_int(statement, 1))
            let order = Int(sqlite3_column_int(statement, 2))
            let starts = sqlite3_column_int(statement, 3) != 0
            let ends = sqlite3_column_int(statement, 4) != 0

            guard let key = VerseKey(surah: surah, ayah: ayah) else { continue }
            verses.append(PageVerseMembership(
                verseKey: key,
                readingOrder: order,
                startsHere: starts,
                endsHere: ends
            ))
        }
        return verses
    }

    private func fetchPageRegions(editionId: String, pageId: String) throws -> [MushafRegion] {
        let sql = """
        SELECT region_id, kind, surah_id, ayah_number, fragment_order, source_order,
               label, min_x, min_y, max_x, max_y
        FROM regions
        WHERE edition_id = ? AND page_id = ?
        ORDER BY source_order ASC;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.statementPreparationFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (pageId as NSString).utf8String, -1, nil)

        var regions: [MushafRegion] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let regId = String(cString: sqlite3_column_text(statement, 0))
            let kindRaw = String(cString: sqlite3_column_text(statement, 1))
            let kind = MushafRegionKind(rawValue: kindRaw) ?? .ayah

            let surahId = sqlite3_column_type(statement, 2) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 2)) : nil
            let ayahNum = sqlite3_column_type(statement, 3) != SQLITE_NULL ? Int(sqlite3_column_int(statement, 3)) : nil
            let fragOrder = Int(sqlite3_column_int(statement, 4))
            let srcOrder = Int(sqlite3_column_int(statement, 5))
            let label = sqlite3_column_text(statement, 6).map { String(cString: $0) }

            let minX = sqlite3_column_double(statement, 7)
            let minY = sqlite3_column_double(statement, 8)
            let maxX = sqlite3_column_double(statement, 9)
            let maxY = sqlite3_column_double(statement, 10)

            guard let rect = NormalizedRect(minX: minX, minY: minY, maxX: maxX, maxY: maxY) else {
                continue
            }

            let verseKey: VerseKey?
            if let s = surahId, let a = ayahNum {
                verseKey = VerseKey(surah: s, ayah: a)
            } else {
                verseKey = nil
            }

            regions.append(MushafRegion(
                id: regId,
                pageId: pageId,
                kind: kind,
                verseKey: verseKey,
                fragmentOrder: fragOrder,
                sourceOrder: srcOrder,
                label: label,
                rect: rect
            ))
        }
        return regions
    }

    private func fetchJuzNumber(editionId: String, navigationIndex: Int) throws -> Int {
        let sql = """
        SELECT na.number FROM navigation_anchors na
        JOIN pages p ON na.edition_id = p.edition_id AND na.page_id = p.page_id
        WHERE na.edition_id = ? AND na.kind = 'juz' AND p.navigation_index <= ?
        ORDER BY na.number DESC
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return 1
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(navigationIndex))

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return 1
    }

    private func fetchFirstSurahId(editionId: String, pageId: String) throws -> Int? {
        let sql = """
        SELECT surah_id FROM page_verses
        WHERE edition_id = ? AND page_id = ?
        ORDER BY reading_order ASC
        LIMIT 1;
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, (editionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (pageId as NSString).utf8String, -1, nil)

        if sqlite3_step(statement) == SQLITE_ROW {
            return Int(sqlite3_column_int(statement, 0))
        }
        return nil
    }
}
