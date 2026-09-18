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
