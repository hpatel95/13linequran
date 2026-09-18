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

    func testAyahSelectionAndMultiLineSpanning() async throws {
        // Page 1 lines: Surah 1 Ayah 7 spans lines 6, 7, and 8
        let p1Lines = try await repository.fetchLines(forPage: 1)
        
        let line6 = p1Lines[5] // 0-indexed line 6
        let line7 = p1Lines[6] // 0-indexed line 7
        let line8 = p1Lines[7] // 0-indexed line 8

        let line6Ayah7Words = line6.words.filter { $0.surah == 1 && $0.ayah == 7 }
        let line7Ayah7Words = line7.words.filter { $0.surah == 1 && $0.ayah == 7 }
        let line8Ayah7Words = line8.words.filter { $0.surah == 1 && $0.ayah == 7 }

        XCTAssertFalse(line6Ayah7Words.isEmpty, "Line 6 must contain the beginning of Ayah 7 (صِرَاطَ)")
        XCTAssertFalse(line7Ayah7Words.isEmpty, "Line 7 must contain the middle words of Ayah 7")
        XCTAssertFalse(line8Ayah7Words.isEmpty, "Line 8 must contain the concluding words of Ayah 7")

        // Total words in Al-Fatihah Ayah 7 should sum to 10
        let totalWords = line6Ayah7Words.count + line7Ayah7Words.count + line8Ayah7Words.count
        XCTAssertEqual(totalWords, 10, "Al-Fatihah Ayah 7 contains exactly 10 words/tokens")
    }

    func testJuzTableIntegrity() async throws {
        let juzs = try await repository.fetchJuzs()
        XCTAssertEqual(juzs.count, 30, "The Holy Quran contains exactly 30 canonical Juzs.")

        let juz1 = juzs.first
        XCTAssertEqual(juz1?.id, 1)
        XCTAssertEqual(juz1?.nameTransliteration, "Alif Lam Meem")
        XCTAssertEqual(juz1?.startPage, 1)
        XCTAssertEqual(juz1?.startSurahId, 1)
        XCTAssertEqual(juz1?.startVerseNumber, 1)

        let juz30 = juzs.last
        XCTAssertEqual(juz30?.id, 30)
        XCTAssertEqual(juz30?.nameTransliteration, "'Amma Yatasa'aloon")
        XCTAssertEqual(juz30?.startPage, 818)
        XCTAssertEqual(juz30?.startSurahId, 78)
        XCTAssertEqual(juz30?.startVerseNumber, 1)

        // Monotonically increasing start pages
        for i in 1..<juzs.count {
            XCTAssertGreaterThanOrEqual(juzs[i].startPage, juzs[i - 1].startPage, "Juz \(juzs[i].id) start page must be >= previous Juz start page")
        }
    }

    func testSurahJuzSpansAndSurahJuzIntegrity() async throws {
        let surahs = try await repository.fetchSurahs()
        let spans = try await repository.fetchSurahJuzSpans()

        XCTAssertEqual(spans.count, 114, "All 114 Surahs must have a computed Juz span.")
        XCTAssertEqual(spans[1], "Juz 1", "Al-Fatihah is in Juz 1")
        XCTAssertEqual(spans[2], "Juz 1–3", "Al-Baqarah spans Juz 1 to 3")
        XCTAssertEqual(spans[78], "Juz 30 (Amma)", "An-Naba is in Juz 30 (Amma)")

        // Check Surah starting Juz integrity
        let anNaba = surahs.first { $0.id == 78 }
        XCTAssertEqual(anNaba?.juzNumber, 30, "An-Naba must start in Juz 30")

        let anNas = surahs.first { $0.id == 114 }
        XCTAssertEqual(anNas?.juzNumber, 30, "An-Nas must be in Juz 30")
    }

    func testFTS5SearchIncludesPageNumber() async throws {
        let results = try await repository.search(query: "Merciful", limit: 5)
        XCTAssertFalse(results.isEmpty)
        guard let first = results.first else { return }
        XCTAssertEqual(first.pageNumber, 1, "Al-Fatihah 1:1 match must indicate page 1 directly from FTS5 index")
    }

    func testFinalPageAndSurahAnNas() async throws {
        let anNas = try await repository.fetchAyahs(forSurah: 114)
        XCTAssertEqual(anNas.count, 6, "Surah An-Nas has 6 canonical ayahs")

        let surahs = try await repository.fetchSurahs()
        let surah114 = surahs.first { $0.id == 114 }
        XCTAssertEqual(surah114?.startPage, 849, "Surah An-Nas must start on page 849 in the 13-line Qudratullah edition")

        let p849Lines = try await repository.fetchLines(forPage: 849)
        XCTAssertEqual(p849Lines.count, 13, "Page 849 must contain exactly 13 lines")

        // Final Ayah of the Quran (6236) must be on Page 849
        let lastAyah = anNas.last
        XCTAssertEqual(lastAyah?.id, 6236, "Final Ayah global ID must be 6236")
        XCTAssertEqual(lastAyah?.pageNumber, 849, "Final Ayah of the Quran (114:6) must reside on Page 849")
    }
}

