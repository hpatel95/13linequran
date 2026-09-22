//
//  EditorialMetadataTests.swift
//  QuranAppTests
//
//  Verification of physical Mushaf editorial metadata (Rukus, rubrics, frontispiece, and margin directions).
//

import XCTest
@testable import QuranApp

final class EditorialMetadataTests: XCTestCase {
    private let service = MushafEditorialService.shared

    func testPage1AlFatihahFrontispiece() {
        let marks = service.marks(for: 1)
        XCTAssertTrue(marks.hasFrontispiece, "Page 1 must be marked as frontispiece")
        XCTAssertEqual(marks.rukuMarks.count, 1, "Page 1 has 1 Ruku at Al-Fatihah conclusion")
        let ruku = marks.rukuMarks.first!
        XCTAssertEqual(ruku.lineNumber, 8)
        XCTAssertEqual(ruku.rukuInSurah, 1)
        XCTAssertEqual(ruku.ayahsInRuku, 7)
        XCTAssertEqual(ruku.rukuInJuz, 1)
        XCTAssertTrue(MushafEditorialService.isOuterMarginOnRight(pageNumber: 1), "Odd page 1 outer margin is on Right")
    }

    func testPage2AlBaqarahOpeningFrontispiece() {
        let marks = service.marks(for: 2)
        XCTAssertTrue(marks.hasFrontispiece, "Page 2 must be marked as frontispiece")
        XCTAssertEqual(marks.rukuMarks.count, 0, "Page 2 has no Ruku conclusion (Ruku 1 ends on Page 3)")
        XCTAssertFalse(MushafEditorialService.isOuterMarginOnRight(pageNumber: 2), "Even page 2 outer margin is on Left")
    }

    func testPage3AlBaqarahRuku1Mark() {
        let marks = service.marks(for: 3)
        XCTAssertFalse(marks.hasFrontispiece, "Page 3 is standard text layout")
        XCTAssertEqual(marks.rukuMarks.count, 1, "Page 3 has Ruku 1 conclusion at Line 5")
        let ruku = marks.rukuMarks.first!
        XCTAssertEqual(ruku.lineNumber, 5, "Ruku 1 concludes on Line 5 (verse 2:7)")
        XCTAssertEqual(ruku.surahId, 2)
        XCTAssertEqual(ruku.rukuInSurah, 1, "Top numeral: 1st Ruku of Surah Al-Baqarah")
        XCTAssertEqual(ruku.ayahsInRuku, 7, "Middle numeral: 7 ayahs in this Ruku")
        XCTAssertEqual(ruku.rukuInJuz, 2, "Bottom numeral: 2nd Ruku of Juz 1")
        XCTAssertTrue(MushafEditorialService.isOuterMarginOnRight(pageNumber: 3), "Odd page 3 outer margin is on Right")
    }

    func testPage4ContinuousTextNoRukuMark() {
        let marks = service.marks(for: 4)
        XCTAssertFalse(marks.hasFrontispiece)
        XCTAssertEqual(marks.rukuMarks.count, 0, "Page 4 is continuous reading text with no Ruku breaks")
        XCTAssertFalse(MushafEditorialService.isOuterMarginOnRight(pageNumber: 4), "Even page 4 outer margin is on Left")
    }

    func testPage5AlBaqarahRuku2Mark() {
        let marks = service.marks(for: 5)
        XCTAssertFalse(marks.hasFrontispiece)
        XCTAssertEqual(marks.rukuMarks.count, 1, "Page 5 has Ruku 2 conclusion at Line 1")
        let ruku = marks.rukuMarks.first!
        XCTAssertEqual(ruku.lineNumber, 1, "Ruku 2 concludes on Line 1 (verse 2:20)")
        XCTAssertEqual(ruku.surahId, 2)
        XCTAssertEqual(ruku.rukuInSurah, 2, "Top numeral: 2nd Ruku of Surah Al-Baqarah")
        XCTAssertEqual(ruku.ayahsInRuku, 13, "Middle numeral: 13 ayahs in this Ruku (2:8 to 2:20)")
        XCTAssertEqual(ruku.rukuInJuz, 3, "Bottom numeral: 3rd Ruku of Juz 1")
        XCTAssertTrue(MushafEditorialService.isOuterMarginOnRight(pageNumber: 5), "Odd page 5 outer margin is on Right")
    }

    func testSurahCartoucheDefaultRukus() {
        XCTAssertEqual(SurahCartoucheView.defaultRukus(for: 1), 1)
        XCTAssertEqual(SurahCartoucheView.defaultRukus(for: 2), 40)
        XCTAssertEqual(SurahCartoucheView.defaultRukus(for: 3), 20)
        XCTAssertEqual(SurahCartoucheView.defaultRukus(for: 114), 1)
    }

    func testEasternArabicDigitsFormatting() {
        XCTAssertEqual(AppTypography.easternArabicDigits(0), "\u{0660}")
        XCTAssertEqual(AppTypography.easternArabicDigits(7), "\u{0667}")
        XCTAssertEqual(AppTypography.easternArabicDigits(13), "\u{0661}\u{0663}")
        XCTAssertEqual(AppTypography.easternArabicDigits(286), "\u{0662}\u{0668}\u{0666}")
    }
}
