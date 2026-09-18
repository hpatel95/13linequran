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
    public let arabicName: String        // e.g. "الفاتحة"
    public let englishName: String       // e.g. "Al-Fatihah"
    public let frenchName: String        // e.g. "L'ouverture"
    public let englishMeaning: String    // e.g. "The Opener"
    public let revelationType: RevelationType
    public let totalVerses: Int          // e.g. 7
    public let startPage: Int            // Starting 13-line page (1 ... 849)
    public let juzNumber: Int            // Starting Juz (1 ... 30)

    public enum RevelationType: String, Sendable, Codable {
        case meccan = "Meccan"
        case medinan = "Medinan"
    }

    public init(
        id: Int,
        arabicName: String,
        englishName: String,
        frenchName: String,
        englishMeaning: String,
        revelationType: RevelationType,
        totalVerses: Int,
        startPage: Int,
        juzNumber: Int
    ) {
        self.id = id
        self.arabicName = arabicName
        self.englishName = englishName
        self.frenchName = frenchName
        self.englishMeaning = englishMeaning
        self.revelationType = revelationType
        self.totalVerses = totalVerses
        self.startPage = startPage
        self.juzNumber = juzNumber
    }
}

// MARK: - Ayah (Verse)
public struct Ayah: Identifiable, Hashable, Sendable, Codable {
    public let id: Int                   // Canonical global verse index: 1 ... 6236
    public let surahId: Int              // 1 ... 114
    public let verseNumber: Int          // 1 ... N (relative to Surah)
    public let pageNumber: Int           // 1 ... 849 (13-line page)
    public let juzNumber: Int            // 1 ... 30
    public let hizbQuarter: Int          // 1 ... 240
    public let sajdah: Bool              // True if verse contains Sajdah
    public let textIndopak: String       // Verified Indo-Pak calligraphic text
    public let textClean: String         // Normalized Imlaei search text

    public var verseKey: String {
        "\(surahId):\(verseNumber)"
    }

    public init(
        id: Int,
        surahId: Int,
        verseNumber: Int,
        pageNumber: Int,
        juzNumber: Int,
        hizbQuarter: Int,
        sajdah: Bool,
        textIndopak: String,
        textClean: String
    ) {
        self.id = id
        self.surahId = surahId
        self.verseNumber = verseNumber
        self.pageNumber = pageNumber
        self.juzNumber = juzNumber
        self.hizbQuarter = hizbQuarter
        self.sajdah = sajdah
        self.textIndopak = textIndopak
        self.textClean = textClean
    }
}

// MARK: - Mushaf Word
public struct MushafWord: Identifiable, Hashable, Sendable, Codable {
    public var id: String { location }
    public let surah: Int
    public let ayah: Int
    public let word: Int
    public let location: String
    public let text: String

    public var verseKey: String { "\(surah):\(ayah)" }

    public init(surah: Int, ayah: Int, word: Int, location: String, text: String) {
        self.surah = surah
        self.ayah = ayah
        self.word = word
        self.location = location
        self.text = text
    }
}

// MARK: - Mushaf Line (13-Line Physical Page Structure)
public struct MushafLine: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let pageNumber: Int           // 1 ... 849
    public let lineNumber: Int           // 1 ... 13
    public let lineType: LineType
    public let surahId: Int?
    public let isCentered: Bool
    public let textIndopak: String
    public let words: [MushafWord]

    public enum LineType: String, Sendable, Codable {
        case ayahText = "ayah_text"
        case surahName = "surah_name"
        case bismillah = "bismillah"
    }

    public init(
        id: Int,
        pageNumber: Int,
        lineNumber: Int,
        lineType: LineType,
        surahId: Int?,
        isCentered: Bool,
        textIndopak: String,
        words: [MushafWord] = []
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.lineNumber = lineNumber
        self.lineType = lineType
        self.surahId = surahId
        self.isCentered = isCentered
        self.textIndopak = textIndopak
        self.words = words
    }
}

// MARK: - Translation
public struct Translation: Identifiable, Hashable, Sendable, Codable {
    public let id: Int
    public let ayahId: Int               // Global verse ID reference (1 ... 6236)
    public let lang: String              // "en" or "fr"
    public let authorCode: TranslationAuthor
    public let text: String

    public enum TranslationAuthor: String, Sendable, Codable, CaseIterable {
        case saheeh = "saheeh"
        case hilaliKhan = "hilali_khan"
        case hamidullah = "hamidullah"

        public var displayName: String {
            switch self {
            case .saheeh:
                return "Saheeh International"
            case .hilaliKhan:
                return "Dr. Hilali & Dr. Muhsin Khan"
            case .hamidullah:
                return "Dr. Muhammad Hamidullah (Français)"
            }
        }
    }

    public init(
        id: Int,
        ayahId: Int,
        lang: String,
        authorCode: TranslationAuthor,
        text: String
    ) {
        self.id = id
        self.ayahId = ayahId
        self.lang = lang
        self.authorCode = authorCode
        self.text = text
    }
}

// MARK: - Search Result (FTS5 Match)
public struct SearchResult: Identifiable, Hashable, Sendable, Codable {
    public var id: Int { ayahId }
    public let ayahId: Int
    public let surahId: Int
    public let verseNumber: Int
    public let arabicClean: String
    public let translationEnSaheeh: String
    public let translationEnHilali: String
    public let translationFrHamidullah: String

    public var verseKey: String {
        "\(surahId):\(verseNumber)"
    }

    public init(
        ayahId: Int,
        surahId: Int,
        verseNumber: Int,
        arabicClean: String,
        translationEnSaheeh: String,
        translationEnHilali: String,
        translationFrHamidullah: String
    ) {
        self.ayahId = ayahId
        self.surahId = surahId
        self.verseNumber = verseNumber
        self.arabicClean = arabicClean
        self.translationEnSaheeh = translationEnSaheeh
        self.translationEnHilali = translationEnHilali
        self.translationFrHamidullah = translationFrHamidullah
    }
}
