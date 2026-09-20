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
        // Prefer the bundle copy (unit tests run hosted inside the app bundle),
        // then fall back to the repository-relative path.
        if let bundled = Bundle.main.path(forResource: "quran_content", ofType: "sqlite") {
            self.repository = try QuranDatabaseService(databaseURL: URL(fileURLWithPath: bundled))
        } else {
            let dbURL = URL(fileURLWithPath: "QuranApp/Resources/Database/quran_content.sqlite")
            self.repository = try QuranDatabaseService(databaseURL: dbURL)
        }
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
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
        XCTAssertEqual(p1Lines[0].lineType, .surahName, "Page 1 Line 1 must be the Surah Name header.")

        // Page 1 Line 2 is verbatim Al-Fatihah 1:1 rendered as a centered Ayah row.
        // It must remain selectable text rather than a decorative Bismillah glyph,
        // otherwise 1:1 could never be long-pressed for its translation.
        XCTAssertEqual(p1Lines[1].lineType, .ayahText, "Page 1 Line 2 must be the centered text of Ayah 1:1.")
        XCTAssertTrue(p1Lines[1].isCentered, "Al-Fatihah 1:1 is typeset as a centered row.")
        XCTAssertEqual(Set(p1Lines[1].words.map(\.verseKey)), ["1:1"], "Page 1 Line 2 must own exactly Ayah 1:1.")
        XCTAssertFalse(p1Lines[1].words.isEmpty, "Al-Fatihah 1:1 must be selectable Ayah text, not a decorative row.")

        // Pages 1, 2 and 849 end with five deliberately unprinted slots.
        for page in [1, 2, 849] {
            let lines = try await repository.fetchLines(forPage: page)
            let blank = lines.filter { $0.lineType == .ayahText && $0.words.isEmpty }
            XCTAssertEqual(blank.count, 5, "Page \(page) must preserve its five empty source slots.")
            XCTAssertEqual(blank.map(\.lineNumber), [9, 10, 11, 12, 13], "Page \(page) empty slots must be rows 9-13.")
        }

        // Page 2 Line 2 is the decorative Bismillah row for Al-Baqarah.
        let p2Lines = try await repository.fetchLines(forPage: 2)
        XCTAssertEqual(p2Lines.count, 13, "Page 2 must contain exactly 13 lines.")
        XCTAssertEqual(p2Lines[1].lineType, .bismillah, "Page 2 Line 2 must be the Al-Baqarah Bismillah.")
        XCTAssertTrue(p2Lines[1].words.isEmpty, "The decorative Bismillah row owns no selectable words.")

        // Page 849 (Final page)
        let p849Lines = try await repository.fetchLines(forPage: 849)
        XCTAssertEqual(p849Lines.count, 13, "Page 849 must contain exactly 13 lines.")
    }

    func testEveryAyahRowReconstructsExactlyFromItsWordTokens() async throws {
        // Guards the invariant that layout/hit-test geometry depends on: the word
        // tokens must be a lossless, ordered partition of the printed row text.
        for page in [1, 2, 4, 28, 105, 610, 613, 849] {
            for line in try await repository.fetchLines(forPage: page) where line.lineType == .ayahText && !line.words.isEmpty {
                let rebuilt = line.words.map(\.text).joined(separator: " ")
                XCTAssertEqual(
                    rebuilt.utf16.count, line.textIndopak.utf16.count,
                    "Page \(page) row \(line.lineNumber) word tokens must rebuild the printed row exactly."
                )
                XCTAssertEqual(
                    Set(line.words.map(\.location)).count, line.words.count,
                    "Page \(page) row \(line.lineNumber) must not repeat a word location."
                )
                for word in line.words {
                    XCTAssertEqual(word.location, "\(word.surah):\(word.ayah):\(word.word)")
                    XCTAssertFalse(word.text.isEmpty)
                }
            }
        }
    }

    func testSharedRowsCarryMoreThanOneAyah() async throws {
        // The previous renderer selected `line.words.first`, which is wrong on any
        // row containing two Ayahs. Page 28 row 10 is the canonical regression case.
        let p28 = try await repository.fetchLines(forPage: 28)
        guard let mixed = p28.first(where: { $0.lineNumber == 10 }) else {
            return XCTFail("Page 28 row 10 must exist.")
        }
        XCTAssertEqual(Set(mixed.words.map(\.verseKey)), ["2:143", "2:144"])
        XCTAssertNotEqual(mixed.words.first?.verseKey, mixed.words.last?.verseKey)
    }

    func testYasinBeginsOnPage610InTheQudratullahEdition() async throws {
        let yasin = try await repository.fetchSurah(id: 36)
        XCTAssertEqual(yasin?.startPage, 610, "Surah YaSin starts on page 610 of this 849-page edition.")
        let lines = try await repository.fetchLines(forPage: 610)
        XCTAssertTrue(lines.contains { $0.lineType == .surahName && $0.surahId == 36 })
        XCTAssertFalse(lines.contains { $0.lineType == .surahName && $0.surahId == 37 })
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

