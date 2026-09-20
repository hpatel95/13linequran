//
//  UserModels.swift
//  QuranApp
//
//  Immutable, thread-safe user data models for bookmarks, reading sessions,
//  and user preferences conforming to Swift 6 Sendable and Codable standards.
//

import Foundation

// MARK: - Bookmark (Ayah or Page level)
public struct Bookmark: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let ayahId: Int?
    public let surahId: Int?
    public let verseNumber: Int?
    public let pageNumber: Int
    public let title: String
    public let arabicSnippet: String?
    public let translationSnippet: String?
    public let note: String?
    public let createdAt: Date

    public var isPageBookmark: Bool {
        ayahId == nil
    }

    public var verseKey: String? {
        guard let s = surahId, let v = verseNumber else { return nil }
        return "\(s):\(v)"
    }

    public init(
        id: Int,
        ayahId: Int? = nil,
        surahId: Int? = nil,
        verseNumber: Int? = nil,
        pageNumber: Int,
        title: String,
        arabicSnippet: String? = nil,
        translationSnippet: String? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ayahId = ayahId
        self.surahId = surahId
        self.verseNumber = verseNumber
        self.pageNumber = pageNumber
        self.title = title
        self.arabicSnippet = arabicSnippet
        self.translationSnippet = translationSnippet
        self.note = note
        self.createdAt = createdAt
    }
}

// MARK: - Reading Session Log
public struct ReadingSessionEntry: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let pageNumber: Int
    public let startTime: Date
    public let durationSeconds: Double

    public init(
        id: Int,
        pageNumber: Int,
        startTime: Date,
        durationSeconds: Double
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.startTime = startTime
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Reader Bookmark V2 (Edition-aware)
public struct ReaderBookmark: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let editionId: String
    public let pageId: String
    public let anchorSurahId: Int?
    public let anchorVerseNumber: Int?
    public let title: String
    public let arabicSnippet: String?
    public let translationSnippet: String?
    public let note: String?
    public let legacyPageNumber: Int?
    public let createdAt: Date

    public var isPageBookmark: Bool {
        anchorSurahId == nil || anchorVerseNumber == nil
    }

    public var verseKey: VerseKey? {
        guard let s = anchorSurahId, let a = anchorVerseNumber else { return nil }
        return VerseKey(surah: s, ayah: a)
    }

    public init(
        id: Int,
        editionId: String,
        pageId: String,
        anchorSurahId: Int? = nil,
        anchorVerseNumber: Int? = nil,
        title: String,
        arabicSnippet: String? = nil,
        translationSnippet: String? = nil,
        note: String? = nil,
        legacyPageNumber: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.editionId = editionId
        self.pageId = pageId
        self.anchorSurahId = anchorSurahId
        self.anchorVerseNumber = anchorVerseNumber
        self.title = title
        self.arabicSnippet = arabicSnippet
        self.translationSnippet = translationSnippet
        self.note = note
        self.legacyPageNumber = legacyPageNumber
        self.createdAt = createdAt
    }
}
