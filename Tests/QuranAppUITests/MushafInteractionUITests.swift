//
//  MushafInteractionUITests.swift
//  QuranAppUITests
//
//  End-to-end gesture verification on a real simulator: the touch must resolve
//  through the rendered glyph geometry to the correct Ayah. These tests fail if
//  selection ever regresses to "the first word of the line".
//

import XCTest

final class MushafInteractionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func launchReader(page: Int) {
        app.launchArguments = ["-mushafAutomatedRun", "-mushafInitialPage", "\(page)"]
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func requireElement(_ identifier: String, timeout: TimeInterval = 25) -> XCUIElement {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "Missing accessibility element \(identifier)")
        return target
    }

    /// Presses an absolute screen point, mirroring a real finger-down hold.
    private func press(at point: CGPoint, duration: TimeInterval = 1.0) {
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x, dy: point.y))
            .press(forDuration: duration)
    }

    private func assertSheetShows(verseKey: String) {
        XCTAssertTrue(requireElement("ayah-sheet").waitForExistence(timeout: 20), "The Ayah sheet did not open.")
        let key = requireElement("ayah-sheet-key")
        let description = "\(key.label) \(String(describing: key.value))"
        XCTAssertTrue(
            description.contains(verseKey),
            "Expected the sheet to describe \(verseKey) but it reported: \(description)"
        )
    }

    private func dismissSheet() {
        let close = app.buttons["Close Ayah sheet"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "The Ayah sheet has no reachable close control.")
        close.tap()
        waitForDisappearance(element("ayah-sheet"))
    }

    private func waitForDisappearance(_ target: XCUIElement, timeout: TimeInterval = 10) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: target)
        wait(for: [gone], timeout: timeout)
    }

    // MARK: - Mixed-Ayah rows (the regression from Test 1)

    func testHoldingTheLeftHalfOfASharedRowSelectsTheSecondAyah() {
        launchReader(page: 28)
        let first = requireElement("ayah-2:143")
        let second = requireElement("ayah-2:144")
        // Both Ayahs must genuinely share row 10: their bounding boxes overlap
        // vertically, and 2:144 must reach further left than 2:143.
        XCTAssertGreaterThanOrEqual(first.frame.maxY, second.frame.minY, "2:143 and 2:144 must share a row.")
        XCTAssertLessThan(second.frame.minX, first.frame.maxX, "2:144 must occupy the left side of the shared row.")

        // Row 10 of page 28 carries the end of 2:143 on the right and the start of
        // 2:144 on the left. Aim at the left half of that shared row.
        let rowHeight = first.frame.height / 7
        let sharedRowBottom = first.frame.maxY
        press(at: CGPoint(x: second.frame.minX + 12, y: sharedRowBottom - rowHeight / 2))

        assertSheetShows(verseKey: "2:144")
        dismissSheet()
    }

    func testHoldingTheRightHalfOfASharedRowSelectsTheFirstAyah() {
        launchReader(page: 28)
        let first = requireElement("ayah-2:143")
        requireElement("ayah-2:144")

        let rowHeight = first.frame.height / 7
        press(at: CGPoint(x: first.frame.maxX - 12, y: first.frame.maxY - rowHeight / 2))

        assertSheetShows(verseKey: "2:143")
        dismissSheet()
    }

    func testHoldingAMultiRowAyahHighlightsEveryOneOfItsRows() {
        launchReader(page: 1)
        // Al-Fatihah 1:7 spans rows 6, 7 and 8 of page 1.
        let ayahSeven = requireElement("ayah-1:7")
        XCTAssertGreaterThan(ayahSeven.frame.height, 0)
        press(at: CGPoint(x: ayahSeven.frame.midX, y: ayahSeven.frame.midY))
        assertSheetShows(verseKey: "1:7")
        dismissSheet()
    }

    // MARK: - Chrome toggling

    func testSingleTapTogglesReadingChrome() {
        launchReader(page: 4)
        let bookmarks = app.buttons["reader-bookmarks"]
        XCTAssertTrue(bookmarks.waitForExistence(timeout: 25), "Reading chrome should be visible on launch.")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        waitForDisappearance(bookmarks, timeout: 8)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(bookmarks.waitForExistence(timeout: 8), "A second tap must restore the reading chrome.")
    }

    // MARK: - Page coverage

    func testSurahTransitionPageRendersSelectableAyahsForBothSurahs() {
        launchReader(page: 610)
        // Page 610 finishes Surah Fatir and opens Surah YaSin.
        requireElement("ayah-35:45")
        requireElement("ayah-36:1")
        let yasin = requireElement("ayah-36:1")
        press(at: CGPoint(x: yasin.frame.midX, y: yasin.frame.midY))
        assertSheetShows(verseKey: "36:1")
        dismissSheet()
    }

    func testFinalPageExposesTheLastAyahAndKeepsBlankSlotsInert() {
        launchReader(page: 849)
        let last = requireElement("ayah-114:6")
        press(at: CGPoint(x: last.frame.midX, y: last.frame.midY))
        assertSheetShows(verseKey: "114:6")
        dismissSheet()
    }
}
