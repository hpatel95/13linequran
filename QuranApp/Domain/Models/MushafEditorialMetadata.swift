//
//  MushafEditorialMetadata.swift
//  QuranApp
//
//  Domain models for traditional 13-line physical Mushaf editorial decorations,
//  including margin Ruku notations (ع), Juz opening medallions, Hizb quarters,
//  Sajdah badges, and Manzil indicators.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

// MARK: - Ruku Mark (Ain Notation in Margin)
public struct RukuMark: Identifiable, Hashable, Sendable, Codable {
    public var id: String { "\(pageNumber):\(lineNumber):\(surahId):\(rukuInSurah)" }
    public let pageNumber: Int
    public let lineNumber: Int
    public let surahId: Int
    public let rukuInSurah: Int     // Top number: Ruku count within Surah
    public let ayahsInRuku: Int     // Middle number: Total Ayahs in this Ruku
    public let rukuInJuz: Int       // Bottom number: Cumulative Ruku count within Juz

    public init(
        pageNumber: Int,
        lineNumber: Int,
        surahId: Int,
        rukuInSurah: Int,
        ayahsInRuku: Int,
        rukuInJuz: Int
    ) {
        self.pageNumber = pageNumber
        self.lineNumber = lineNumber
        self.surahId = surahId
        self.rukuInSurah = rukuInSurah
        self.ayahsInRuku = ayahsInRuku
        self.rukuInJuz = rukuInJuz
    }
}

// MARK: - Margin Rubric (Juz, Hizb Quarter, Sajdah, Manzil)
public struct MarginRubric: Identifiable, Hashable, Sendable, Codable {
    public var id: String { "\(pageNumber):\(lineNumber):\(kindDescription)" }
    public let pageNumber: Int
    public let lineNumber: Int
    public let kind: RubricKind

    public enum RubricKind: Hashable, Sendable, Codable {
        case juzStart(number: Int, arabicName: String)
        case quarter(QuarterType)
        case sajdah(number: Int)
        case manzil(number: Int)
        case middleOfQuran
        case muanaqah

        public var isJuzStart: Bool {
            if case .juzStart = self { return true }
            return false
        }
    }

    public enum QuarterType: String, Hashable, Sendable, Codable {
        case rub = "رُبْع"          // 1st quarter (1/4)
        case nisf = "نِصْف"         // 2nd quarter (1/2)
        case thalatha = "ثَلَاثَة"    // 3rd quarter (3/4)
    }

    private var kindDescription: String {
        switch kind {
        case .juzStart(let num, _): return "juz_\(num)"
        case .quarter(let q): return "quarter_\(q.rawValue)"
        case .sajdah(let num): return "sajdah_\(num)"
        case .manzil(let num): return "manzil_\(num)"
        case .middleOfQuran: return "nisf_al_quran"
        case .muanaqah: return "muanaqah"
        }
    }

    public init(pageNumber: Int, lineNumber: Int, kind: RubricKind) {
        self.pageNumber = pageNumber
        self.lineNumber = lineNumber
        self.kind = kind
    }
}

// MARK: - Page Editorial Marks
public struct PageEditorialMarks: Hashable, Sendable {
    public let pageNumber: Int
    public let rukuMarks: [RukuMark]
    public let rubrics: [MarginRubric]
    public let hasFrontispiece: Bool

    public init(
        pageNumber: Int,
        rukuMarks: [RukuMark] = [],
        rubrics: [MarginRubric] = [],
        hasFrontispiece: Bool = false
    ) {
        self.pageNumber = pageNumber
        self.rukuMarks = rukuMarks
        self.rubrics = rubrics
        self.hasFrontispiece = hasFrontispiece
    }

    public static let empty = PageEditorialMarks(pageNumber: 0)
}
