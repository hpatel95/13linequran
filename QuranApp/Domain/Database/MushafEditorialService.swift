//
//  MushafEditorialService.swift
//  QuranApp
//
//  In-memory editorial metadata provider for physical 13-line Mushaf decorations.
//  Provides O(1) lookup for margin Ruku badges, rubrics (Juz, Quarters, Sajdahs, Manzils),
//  and illuminated frontispiece indicators without modifying the canonical SQLite database.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

public final class MushafEditorialService: Sendable {
    public static let shared = MushafEditorialService()

    /// Precomputed cache of editorial marks keyed by page number.
    private let pageMarks: [Int: PageEditorialMarks]

    public init() {
        var marks: [Int: PageEditorialMarks] = [:]

        // MARK: - Page 1: Surah Al-Fatihah Frontispiece
        marks[1] = PageEditorialMarks(
            pageNumber: 1,
            rukuMarks: [
                RukuMark(pageNumber: 1, lineNumber: 8, surahId: 1, rukuInSurah: 1, ayahsInRuku: 7, rukuInJuz: 1)
            ],
            rubrics: [
                MarginRubric(pageNumber: 1, lineNumber: 1, kind: .juzStart(number: 1, arabicName: "الم"))
            ],
            hasFrontispiece: true
        )

        // MARK: - Page 2: Surah Al-Baqarah Opening Frontispiece
        marks[2] = PageEditorialMarks(
            pageNumber: 2,
            rukuMarks: [],
            rubrics: [
                MarginRubric(pageNumber: 2, lineNumber: 3, kind: .muanaqah)
            ],
            hasFrontispiece: true
        )

        // MARK: - Page 3: Surah Al-Baqarah (Ruku 1 ends at Line 5)
        marks[3] = PageEditorialMarks(
            pageNumber: 3,
            rukuMarks: [
                RukuMark(pageNumber: 3, lineNumber: 5, surahId: 2, rukuInSurah: 1, ayahsInRuku: 7, rukuInJuz: 2)
            ],
            rubrics: [],
            hasFrontispiece: false
        )

        // MARK: - Page 4: Surah Al-Baqarah (Continuous reading text)
        marks[4] = PageEditorialMarks(
            pageNumber: 4,
            rukuMarks: [],
            rubrics: [],
            hasFrontispiece: false
        )

        // MARK: - Page 5: Surah Al-Baqarah (Ruku 2 ends at Line 1)
        marks[5] = PageEditorialMarks(
            pageNumber: 5,
            rukuMarks: [
                RukuMark(pageNumber: 5, lineNumber: 1, surahId: 2, rukuInSurah: 2, ayahsInRuku: 13, rukuInJuz: 3)
            ],
            rubrics: [],
            hasFrontispiece: false
        )

        // MARK: - Page 6: Surah Al-Baqarah (Ruku 3 ends at Line 11, Rub' 1 start at Line 1)
        marks[6] = PageEditorialMarks(
            pageNumber: 6,
            rukuMarks: [
                RukuMark(pageNumber: 6, lineNumber: 11, surahId: 2, rukuInSurah: 3, ayahsInRuku: 9, rukuInJuz: 4)
            ],
            rubrics: [
                MarginRubric(pageNumber: 6, lineNumber: 1, kind: .quarter(.rub))
            ],
            hasFrontispiece: false
        )

        // MARK: - Page 28: Start of Juz 2 (Line 10: سَيَقُولُ) & Ruku 17 (Line 9)
        marks[28] = PageEditorialMarks(
            pageNumber: 28,
            rukuMarks: [
                RukuMark(pageNumber: 28, lineNumber: 9, surahId: 2, rukuInSurah: 17, ayahsInRuku: 2, rukuInJuz: 16)
            ],
            rubrics: [
                MarginRubric(pageNumber: 28, lineNumber: 1, kind: .juzStart(number: 2, arabicName: "سَيَقُولُ"))
            ],
            hasFrontispiece: false
        )

        // MARK: - Page 245: First Sajdah Tilawah (Line 1: 7:206)
        marks[245] = PageEditorialMarks(
            pageNumber: 245,
            rukuMarks: [],
            rubrics: [
                MarginRubric(pageNumber: 245, lineNumber: 1, kind: .sajdah(number: 1))
            ],
            hasFrontispiece: false
        )

        // MARK: - Page 411: Surah Al-Kahf 18:19 (Line 1: وَلْيَتَلَطَّفْ / Middle of Quran)
        marks[411] = PageEditorialMarks(
            pageNumber: 411,
            rukuMarks: [],
            rubrics: [
                MarginRubric(pageNumber: 411, lineNumber: 1, kind: .middleOfQuran)
            ],
            hasFrontispiece: false
        )

        // MARK: - Page 849: Surah An-Nas & Tailpiece
        marks[849] = PageEditorialMarks(
            pageNumber: 849,
            rukuMarks: [
                RukuMark(pageNumber: 849, lineNumber: 8, surahId: 114, rukuInSurah: 1, ayahsInRuku: 6, rukuInJuz: 39)
            ],
            rubrics: [],
            hasFrontispiece: true
        )

        self.pageMarks = marks
    }

    /// Retrieve physical editorial marks for a given page.
    public func marks(for pageNumber: Int) -> PageEditorialMarks {
        pageMarks[pageNumber] ?? PageEditorialMarks(pageNumber: pageNumber)
    }

    /// Returns whether a given page is an illuminated frontispiece page.
    public func isFrontispiece(pageNumber: Int) -> Bool {
        marks(for: pageNumber).hasFrontispiece
    }

    /// Returns whether the outer margin for this page is on the Right (odd) or Left (even).
    public static func isOuterMarginOnRight(pageNumber: Int) -> Bool {
        // In authentic RTL codex:
        // Odd pages (1, 3, 5...) are on the right side of the spread -> outer margin is on the Right.
        // Even pages (2, 4, 6...) are on the left side of the spread -> outer margin is on the Left.
        return pageNumber % 2 != 0
    }
}
