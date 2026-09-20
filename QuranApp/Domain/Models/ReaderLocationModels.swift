//
//  ReaderLocationModels.swift
//  QuranApp
//
//  Strongly-typed location and destination representations for authentic
//  facsimile and accessible text reader navigation.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

// MARK: - Navigation Anchor Kind
public enum NavigationAnchorKind: String, Codable, Sendable, CaseIterable {
    case surah = "surah"
    case juz = "juz"
    case rubElHizb = "rub_el_hizb"
    case manzil = "manzil"
}

// MARK: - Reader Location
public struct ReaderLocation: Hashable, Codable, Sendable, Identifiable {
    public var id: String { "\(editionId):\(pageId)" }

    public let editionId: String
    public let pageId: String
    public let navigationIndex: Int   // 1 ... totalPages (e.g. 1...848)
    public let quranOrdinal: Int?     // 1 ... 847 (nil for supplement/dua)
    public let surahId: Int?          // Primary or anchor Surah (1...114)
    public let juzNumber: Int?        // Juz number (1...30)
    public let focusedVerse: VerseKey? // Specific target verse on this page, if any
    public let label: String?         // Printed page label e.g. "4"

    public init(
        editionId: String,
        pageId: String,
        navigationIndex: Int,
        quranOrdinal: Int? = nil,
        surahId: Int? = nil,
        juzNumber: Int? = nil,
        focusedVerse: VerseKey? = nil,
        label: String? = nil
    ) {
        self.editionId = editionId
        self.pageId = pageId
        self.navigationIndex = navigationIndex
        self.quranOrdinal = quranOrdinal
        self.surahId = surahId
        self.juzNumber = juzNumber
        self.focusedVerse = focusedVerse
        self.label = label
    }

    /// Returns a copy of this location with an updated focused verse.
    public func focusing(verse: VerseKey?) -> ReaderLocation {
        ReaderLocation(
            editionId: editionId,
            pageId: pageId,
            navigationIndex: navigationIndex,
            quranOrdinal: quranOrdinal,
            surahId: surahId,
            juzNumber: juzNumber,
            focusedVerse: verse,
            label: label
        )
    }

    /// Returns a user-visible title for the navigation bar or header.
    public var displayTitle: String {
        if let ordinal = quranOrdinal {
            return "Page \(ordinal)"
        } else if let label = label, !label.isEmpty {
            return label
        } else {
            return "Page \(navigationIndex)"
        }
    }
}

// MARK: - Reader Destination
public enum ReaderDestination: Hashable, Sendable {
    case page(navigationIndex: Int)
    case quranOrdinal(Int)
    case surah(surahId: Int, ayahNumber: Int? = nil)
    case juz(juzNumber: Int)
    case verse(VerseKey)
    case exact(ReaderLocation)
}
