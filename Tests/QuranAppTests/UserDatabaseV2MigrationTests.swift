//
//  UserDatabaseV2MigrationTests.swift
//  QuranAppTests
//
//  Unit tests verifying V2 transactional migration, edition-isolated bookmarks,
//  and last-read location persistence.
//

import XCTest
@testable import QuranApp

final class UserDatabaseV2MigrationTests: XCTestCase {
    var userDatabase: UserDatabaseService!

    override func setUp() async throws {
        try await super.setUp()
        self.userDatabase = try UserDatabaseService(databasePath: ":memory:")
    }

    override func tearDown() async throws {
        self.userDatabase = nil
        try await super.tearDown()
    }

    func testV2TablesInitialization() async throws {
        let bookmarks = try await userDatabase.fetchReaderBookmarks(editionId: "taj-company-13-847")
        XCTAssertTrue(bookmarks.isEmpty, "Initial bookmarks for edition should be empty")

        let lastLoc = try await userDatabase.fetchReaderLastLocation(editionId: "taj-company-13-847")
        XCTAssertNil(lastLoc, "Initial last location should be nil")
    }

    func testAddAndFetchReaderBookmark() async throws {
        let bookmark = ReaderBookmark(
            id: 0,
            editionId: "taj-company-13-847",
            pageId: "p0001",
            anchorSurahId: 1,
            anchorVerseNumber: 1,
            title: "Al-Fatihah 1:1",
            arabicSnippet: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            translationSnippet: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
            note: "First verse of the Quran",
            legacyPageNumber: 1
        )

        let saved = try await userDatabase.addReaderBookmark(bookmark)
        XCTAssertGreaterThan(saved.id, 0)
        XCTAssertEqual(saved.editionId, "taj-company-13-847")
        XCTAssertEqual(saved.pageId, "p0001")
        XCTAssertEqual(saved.anchorSurahId, 1)
        XCTAssertEqual(saved.anchorVerseNumber, 1)

        let isBookmarked = try await userDatabase.isReaderAyahBookmarked(
            editionId: "taj-company-13-847",
            surahId: 1,
            verseNumber: 1
        )
        XCTAssertTrue(isBookmarked)

        let fetched = try await userDatabase.fetchReaderBookmarks(editionId: "taj-company-13-847")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, saved.id)

        // Querying a different edition should return empty (isolated)
        let otherEdition = try await userDatabase.fetchReaderBookmarks(editionId: "other-edition")
        XCTAssertTrue(otherEdition.isEmpty)

        // Delete bookmark
        try await userDatabase.removeReaderBookmark(id: saved.id)
        let afterDelete = try await userDatabase.fetchReaderBookmarks(editionId: "taj-company-13-847")
        XCTAssertTrue(afterDelete.isEmpty)
    }

    func testSaveAndFetchReaderLastLocation() async throws {
        let loc = ReaderLocation(
            editionId: "taj-company-13-847",
            pageId: "p0042",
            navigationIndex: 42,
            quranOrdinal: 42,
            surahId: 2,
            juzNumber: 3,
            focusedVerse: VerseKey(surah: 2, ayah: 255),
            label: "42"
        )

        try await userDatabase.saveReaderLastLocation(loc)

        let fetched = try await userDatabase.fetchReaderLastLocation(editionId: "taj-company-13-847")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.editionId, "taj-company-13-847")
        XCTAssertEqual(fetched?.pageId, "p0042")
        XCTAssertEqual(fetched?.navigationIndex, 42)
        XCTAssertEqual(fetched?.quranOrdinal, 42)
        XCTAssertEqual(fetched?.surahId, 2)
        XCTAssertEqual(fetched?.juzNumber, 3)
    }
}
