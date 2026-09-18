//
//  QuranModels.swift
//  QuranApp
//
//  Core domain entities for the 13-Line Quran Reader.
//  Thread-safe, Sendable, and Hashable for Swift 6 strict concurrency.
//

import Foundation

// MARK: - Surah (Chapter)
public struct Surah: Identifiable, Hashable, Sendable, Codable {
    public let id: Int                   // 1 ... 114
    public let arabicName: String        // e.g. "سُورَةُ الْمُلْكِ"
    public let englishName: String       // e.g. "Al-Mulk"
    public let englishMeaning: String    // e.g. "The Sovereignty"
    public let revelationType: RevelationType
    public let totalVerses: Int          // e.g. 30
    public let startPage: Int            // Starting 13-line page (1 ... 848)
    public let juzNumber: Int            // Starting Juz (1 ... 30)
    
    public enum RevelationType: String, Sendable, Codable {
        case meccan = "Meccan"
        case medinan = "Medinan"
    }
}

// MARK: - Ayah (Verse)
public struct Ayah: Identifiable, Hashable, Sendable, Codable {
    public let id: Int                   // Canonical global verse index: 1 ... 6236
    public let surahId: Int              // 1 ... 114
    public let verseNumber: Int          // 1 ... N (relative to Surah)
    public let pageNumber: Int           // 1 ... 848 (13-line page)
    public let juzNumber: Int            // 1 ... 30
    public let arabicText: String        // Verified Tanzil Uthmanic/Indo-Pak text
}

// MARK: - AyahBound (13-Line Coordinate Geometry)
public struct AyahBound: Identifiable, Hashable, Sendable, Codable {
    public let id: Int                   // Unique coordinate record ID
    public let ayahId: Int               // Global verse ID reference
    public let pageNumber: Int           // 1 ... 848
    public let lineNumber: Int           // 1 ... 13 (line on the page)
    
    // Normalized coordinates [0.0 ... 1.0] relative to the 1600x2400 page tile
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double
}

// MARK: - Translation (Public Domain)
public struct Translation: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let ayahId: Int               // Verse reference
    public let authorCode: String        // "pickthall_1930", "yusuf_ali_1934", "jalandhari_1944"
    public let text: String
}
