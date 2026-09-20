//
//  UserDatabaseServiceProtocol.swift
//  QuranApp
//
//  Thread-safe repository contract for managing user bookmarks,
//  last-read position, and persistent application preferences.
//

import Foundation

public protocol UserDatabaseServiceProtocol: Sendable {
    // MARK: - Bookmarks
    func fetchBookmarks() async throws -> [Bookmark]
    func isAyahBookmarked(ayahId: Int) async throws -> Bool
    func isPageBookmarked(pageNumber: Int) async throws -> Bool
    func fetchBookmarkedAyahIds() async throws -> Set<Int>
    func addAyahBookmark(
        ayahId: Int,
        surahId: Int,
        verseNumber: Int,
        pageNumber: Int,
        title: String,
        arabic: String,
        translation: String,
        note: String?
    ) async throws -> Bookmark
    func addPageBookmark(pageNumber: Int, title: String, note: String?) async throws -> Bookmark
    func removeBookmark(id: Int) async throws
    func removeAyahBookmark(ayahId: Int) async throws
    func removePageBookmark(pageNumber: Int) async throws

    // MARK: - Last Read & Preferences
    func saveLastReadPage(_ pageNumber: Int) async throws
    func getLastReadPage() async throws -> Int
    func setPreference(key: String, value: String) async throws
    func getPreference(key: String) async throws -> String?

    // MARK: - Reading Sessions
    func recordReadingSession(pageNumber: Int, durationSeconds: Double) async throws
    func fetchRecentPages(limit: Int) async throws -> [Int]

    // MARK: - V2 Edition-Aware Methods
    func fetchReaderBookmarks(editionId: String?) async throws -> [ReaderBookmark]
    func addReaderBookmark(_ bookmark: ReaderBookmark) async throws -> ReaderBookmark
    func removeReaderBookmark(id: Int) async throws
    func isReaderAyahBookmarked(editionId: String, surahId: Int, verseNumber: Int) async throws -> Bool
    func isReaderPageBookmarked(editionId: String, pageId: String) async throws -> Bool
    func saveReaderLastLocation(_ location: ReaderLocation) async throws
    func fetchReaderLastLocation(editionId: String) async throws -> ReaderLocation?
}
