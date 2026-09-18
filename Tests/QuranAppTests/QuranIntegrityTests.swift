//
//  QuranIntegrityTests.swift
//  QuranAppTests
//
//  Comprehensive test suite verifying the database integrity, canonical Surah counts,
//  13-line page mappings, translations, and FTS5 search.
//

import XCTest
@testable import QuranApp

final class QuranIntegrityTests: XCTestCase {
    var repository: QuranRepositoryProtocol!

    override func setUp() async throws {
        try await super.setUp()
        // Connect to the bundled SQLite database
        let dbURL = URL(fileURLWithPath: "QuranApp/Resources/Database/quran_content.sqlite")
        self.repository = try QuranDatabaseService(databaseURL: dbURL)
    }

    func testCanonicalSurahCount() async throws {
        let surahs = try await repository.fetchSurahs()
        XCTAssertEqual(surahs.count, 114, "The Quran must contain exactly 114 Surahs.")
        
        let fatihah = surahs.first
        XCTAssertEqual(fatihah?.id, 1)
        XCTAssertEqual(fatihah?.englishName, "Al-Fatihah")
        XCTAssertEqual(fatihah?.totalVerses, 7)

        let baqarah = surahs[1]
        XCTAssertEqual(baqarah.id, 2)
        XCTAssertEqual(baqarah.totalVerses, 286)

        let nas = surahs.last
        XCTAssertEqual(nas?.id, 114)
        XCTAssertEqual(nas?.englishName, "An-Nas")
        XCTAssertEqual(nas?.totalVerses, 6)
    }

    func testCanonicalAyahCount() async throws {
        var totalAyahs = 0
        let surahs = try await repository.fetchSurahs()
        for s in surahs {
            let ayahs = try await repository.fetchAyahs(forSurah: s.id)
            XCTAssertEqual(ayahs.count, s.totalVerses, "Surah \(s.id) (\(s.englishName)) verse count mismatch")
            totalAyahs += ayahs.count
        }
        XCTAssertEqual(totalAyahs, 6236, "The Quran must contain exactly 6,236 canonical verses.")
    }

    func testPhysical13LinePageBounds() async throws {
        // Page 1
        let p1Lines = try await repository.fetchLines(forPage: 1)
        XCTAssertEqual(p1Lines.count, 13, "Page 1 must contain exactly 13 lines.")
        XCTAssertEqual(p1Lines.first?.lineType, .surahName, "Page 1 Line 1 must be Surah Name header.")
        XCTAssertEqual(p1Lines[1].lineType, .bismillah, "Page 1 Line 2 must be Bismillah.")

        // Page 2 (Al-Baqarah start)
        let p2Lines = try await repository.fetchLines(forPage: 2)
        XCTAssertEqual(p2Lines.count, 13, "Page 2 must contain exactly 13 lines.")

        // Page 849 (Final page)
        let p849Lines = try await repository.fetchLines(forPage: 849)
        XCTAssertEqual(p849Lines.count, 13, "Page 849 must contain exactly 13 lines.")
    }

    func testTranslationsIntegrity() async throws {
        // Al-Fatihah 1:1 global ayah ID = 1
        let saheeh = try await repository.fetchTranslation(ayahId: 1, authorCode: .saheeh)
        XCTAssertNotNil(saheeh)
        XCTAssertTrue(saheeh!.text.contains("Allah"), "Saheeh International 1:1 should contain Allah")

        let hilali = try await repository.fetchTranslation(ayahId: 1, authorCode: .hilaliKhan)
        XCTAssertNotNil(hilali)
        XCTAssertTrue(hilali!.text.contains("Allah"), "Hilali-Khan 1:1 should contain Allah")

        let french = try await repository.fetchTranslation(ayahId: 1, authorCode: .hamidullah)
        XCTAssertNotNil(french)
        XCTAssertTrue(french!.text.contains("Allah"), "Hamidullah 1:1 should contain Allah")
    }

    func testFTS5FullTextSearch() async throws {
        let results = try await repository.search(query: "Merciful", limit: 5)
        XCTAssertFalse(results.isEmpty, "FTS5 search for 'Merciful' should return matches.")
        XCTAssertEqual(results.first?.ayahId, 1, "First match for 'Merciful' should be Al-Fatihah 1:1.")
    }
}
