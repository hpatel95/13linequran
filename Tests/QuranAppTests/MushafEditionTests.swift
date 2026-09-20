//
//  MushafEditionTests.swift
//  QuranAppTests
//
//  Unit tests verifying the authentic Mushaf sidecar database, catalog metadata,
//  page counts, navigation anchors, and interactive Ayah regions.
//

import XCTest
@testable import QuranApp

final class MushafEditionTests: XCTestCase {
    var service: MushafEditionDatabaseService!

    override func setUp() async throws {
        try await super.setUp()
        self.service = try MushafEditionDatabaseService()
    }

    override func tearDown() async throws {
        self.service = nil
        try await super.tearDown()
    }

    func testCatalogAndEditionMetadata() async throws {
        let editions = try await service.fetchEditions()
        XCTAssertFalse(editions.isEmpty, "Editions catalog must not be empty")

        guard let edition = editions.first(where: { $0.id == "taj-company-13-847" }) else {
            XCTFail("taj-company-13-847 edition must exist in catalog")
            return
        }

        XCTAssertEqual(edition.quranPageCount, 847, "Quran page count must be 847")
        XCTAssertEqual(edition.navigationPageCount, 848, "Navigation page count must be 848 (847 Quran + 1 Dua)")
        XCTAssertEqual(edition.rendererKind, .facsimile)
        XCTAssertEqual(edition.approvalStatus, .approved)
    }

    func testPagesContiguityAndRange() async throws {
        let pages = try await service.fetchPages(editionId: "taj-company-13-847")
        XCTAssertEqual(pages.count, 848, "Total pages must be 848")

        // First page (Al-Fatihah)
        let first = pages[0]
        XCTAssertEqual(first.id, "p0001")
        XCTAssertEqual(first.navigationIndex, 1)
        XCTAssertEqual(first.quranOrdinal, 1)
        XCTAssertEqual(first.kind, .quran)

        // Last Quran page (An-Nas)
        let lastQuran = pages[846]
        XCTAssertEqual(lastQuran.id, "p0847")
        XCTAssertEqual(lastQuran.navigationIndex, 847)
        XCTAssertEqual(lastQuran.quranOrdinal, 847)

        // Supplement page (Dua Khatam al-Quran)
        let supplement = pages[847]
        XCTAssertEqual(supplement.id, "p0848")
        XCTAssertEqual(supplement.navigationIndex, 848)
        XCTAssertNil(supplement.quranOrdinal)
        XCTAssertEqual(supplement.kind, .supplement)
    }

    func testSurahNavigationAnchors() async throws {
        // Surah 1 (Al-Fatihah) starts on p0001
        let surah1 = try await service.fetchAnchor(editionId: "taj-company-13-847", kind: .surah, number: 1)
        XCTAssertNotNil(surah1)
        XCTAssertEqual(surah1?.pageId, "p0001")
        XCTAssertEqual(surah1?.navigationIndex, 1)

        // Surah 2 (Al-Baqarah) starts on p0002
        let surah2 = try await service.fetchAnchor(editionId: "taj-company-13-847", kind: .surah, number: 2)
        XCTAssertNotNil(surah2)
        XCTAssertEqual(surah2?.pageId, "p0002")
        XCTAssertEqual(surah2?.navigationIndex, 2)

        // Surah 114 (An-Nas) starts on p0847
        let surah114 = try await service.fetchAnchor(editionId: "taj-company-13-847", kind: .surah, number: 114)
        XCTAssertNotNil(surah114)
        XCTAssertEqual(surah114?.pageId, "p0847")
        XCTAssertEqual(surah114?.navigationIndex, 847)
    }

    func testJuzNavigationAnchors() async throws {
        // Juz 1 starts on p0001
        let juz1 = try await service.fetchAnchor(editionId: "taj-company-13-847", kind: .juz, number: 1)
        XCTAssertNotNil(juz1)
        XCTAssertEqual(juz1?.navigationIndex, 1)

        // Juz 30 starts on an authentic page
        let juz30 = try await service.fetchAnchor(editionId: "taj-company-13-847", kind: .juz, number: 30)
        XCTAssertNotNil(juz30)
        XCTAssertTrue((juz30?.navigationIndex ?? 0) > 800)
    }

    func testPatchedVerseRegionsSurahAshShuara() async throws {
        // Page p0519 contains 26:143 and 26:144 which were patched from 0,0,0,0
        guard let page = try await service.fetchPage(editionId: "taj-company-13-847", pageId: "p0519") else {
            XCTFail("p0519 must exist")
            return
        }

        let verse143Key = VerseKey(surah: 26, ayah: 143)!
        let regions143 = page.regions(for: verse143Key)
        XCTAssertFalse(regions143.isEmpty, "Patched verse 26:143 must have non-empty regions")
        for region in regions143 {
            XCTAssertGreaterThan(region.rect.area, 0, "Patched region must have positive non-zero area")
            XCTAssertLessThanOrEqual(region.rect.maxX, 1.0)
            XCTAssertLessThanOrEqual(region.rect.maxY, 1.0)
        }

        let verse144Key = VerseKey(surah: 26, ayah: 144)!
        let regions144 = page.regions(for: verse144Key)
        XCTAssertFalse(regions144.isEmpty, "Patched verse 26:144 must have non-empty regions")
        for region in regions144 {
            XCTAssertGreaterThan(region.rect.area, 0, "Patched region must have positive non-zero area")
        }
    }
}
