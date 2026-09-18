//
//  UserDatabaseTests.swift
//  QuranAppTests
//
//  Unit tests verifying the user database service, bookmark CRUD operations,
//  duplicate prevention, last-read page persistence, and app preferences.
//

import XCTest
@testable import QuranApp

final class UserDatabaseTests: XCTestCase {
    var userDatabase: UserDatabaseService!

    override func setUp() async throws {
        try await super.setUp()
        // Use an in-memory SQLite database for isolated, lightning-fast tests
        self.userDatabase = try UserDatabaseService(databasePath: ":memory:")
    }

    override func tearDown() async throws {
        self.userDatabase = nil
        try await super.tearDown()
    }

    func testSchemaInitialization() async throws {
        let bookmarks = try await userDatabase.fetchBookmarks()
        XCTAssertTrue(bookmarks.isEmpty, "Initial in-memory database should have empty bookmarks.")
        
        let lastPage = try await userDatabase.getLastReadPage()
        XCTAssertEqual(lastPage, 1, "Default last-read page must be Page 1.")
    }

    func testAddAndFetchAyahBookmark() async throws {
        let bookmark = try await userDatabase.addAyahBookmark(
            ayahId: 262,
            surahId: 2,
            verseNumber: 255,
            pageNumber: 42,
            title: "Al-Baqarah 2:255",
            arabic: "اللَّهُ لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ",
            translation: "Allah! There is no deity except Him, the Ever-Living, the Sustainer of all existence.",
            note: "Ayat al-Kursi"
        )

        XCTAssertEqual(bookmark.ayahId, 262)
        XCTAssertEqual(bookmark.surahId, 2)
        XCTAssertEqual(bookmark.verseNumber, 255)
        XCTAssertEqual(bookmark.pageNumber, 42)
        XCTAssertFalse(bookmark.isPageBookmark)
        XCTAssertEqual(bookmark.note, "Ayat al-Kursi")

        let isSaved = try await userDatabase.isAyahBookmarked(ayahId: 262)
        XCTAssertTrue(isSaved)

        let all = try await userDatabase.fetchBookmarks()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, bookmark.id)

        // Test duplicate prevention
        let duplicate = try await userDatabase.addAyahBookmark(
            ayahId: 262,
            surahId: 2,
            verseNumber: 255,
            pageNumber: 42,
            title: "Al-Baqarah 2:255",
            arabic: "اللَّهُ",
            translation: "Allah",
            note: nil
        )
        XCTAssertEqual(duplicate.id, bookmark.id)
        let countAfterDuplicate = try await userDatabase.fetchBookmarks().count
        XCTAssertEqual(countAfterDuplicate, 1, "Duplicate bookmarks for the same Ayah must not be inserted.")
    }

    func testAddAndFetchPageBookmark() async throws {
        let pageBookmark = try await userDatabase.addPageBookmark(
            pageNumber: 100,
            title: "Page 100 Bookmark",
            note: "Halfway through Surah An-Nisa"
        )

        XCTAssertTrue(pageBookmark.isPageBookmark)
        XCTAssertNil(pageBookmark.ayahId)
        XCTAssertEqual(pageBookmark.pageNumber, 100)

        let isPageSaved = try await userDatabase.isPageBookmarked(pageNumber: 100)
        XCTAssertTrue(isPageSaved)

        let isDifferentPageSaved = try await userDatabase.isPageBookmarked(pageNumber: 101)
        XCTAssertFalse(isDifferentPageSaved)
    }

    func testRemoveBookmark() async throws {
        _ = try await userDatabase.addAyahBookmark(
            ayahId: 1,
            surahId: 1,
            verseNumber: 1,
            pageNumber: 1,
            title: "Al-Fatihah 1:1",
            arabic: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
            translation: "In the name of Allah",
            note: nil
        )

        XCTAssertTrue(try await userDatabase.isAyahBookmarked(ayahId: 1))

        try await userDatabase.removeAyahBookmark(ayahId: 1)
        XCTAssertFalse(try await userDatabase.isAyahBookmarked(ayahId: 1))
        XCTAssertTrue(try await userDatabase.fetchBookmarks().isEmpty)
    }

    func testLastReadPagePersistence() async throws {
        XCTAssertEqual(try await userDatabase.getLastReadPage(), 1)

        try await userDatabase.saveLastReadPage(55)
        XCTAssertEqual(try await userDatabase.getLastReadPage(), 55)

        try await userDatabase.saveLastReadPage(849)
        XCTAssertEqual(try await userDatabase.getLastReadPage(), 849)
    }

    func testAppPreferences() async throws {
        XCTAssertNil(try await userDatabase.getPreference(key: "preferred_reciter"))

        try await userDatabase.setPreference(key: "preferred_reciter", value: "Khalifa Al Tunaiji")
        let reciter = try await userDatabase.getPreference(key: "preferred_reciter")
        XCTAssertEqual(reciter, "Khalifa Al Tunaiji")

        // Overwrite preference
        try await userDatabase.setPreference(key: "preferred_reciter", value: "Mishary Rashid")
        let updatedReciter = try await userDatabase.getPreference(key: "preferred_reciter")
        XCTAssertEqual(updatedReciter, "Mishary Rashid")
    }

    func testReadingSessions() async throws {
        try await userDatabase.recordReadingSession(pageNumber: 1, durationSeconds: 60.0)
        try await userDatabase.recordReadingSession(pageNumber: 2, durationSeconds: 120.0)
        try await userDatabase.recordReadingSession(pageNumber: 3, durationSeconds: 45.0)

        let recentPages = try await userDatabase.fetchRecentPages(limit: 5)
        XCTAssertEqual(recentPages, [3, 2, 1], "Recent pages should be ordered by recency descending.")
    }
}
