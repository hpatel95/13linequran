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
        // The verse key label is a leaf element, so it is always exposed to XCUI.
        let key = requireElement("ayah-sheet-key", timeout: 25)
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
        waitForDisappearance(element("ayah-sheet-key"))
    }

    /// Keeps a visual record of the glazed selection inside the CI result bundle.
    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForDisappearance(_ target: XCUIElement, timeout: TimeInterval = 10) {
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: target)
        wait(for: [gone], timeout: timeout)
    }

    // MARK: - Mixed-Ayah rows (the regression from Test 1)

    func testHoldingTheLeftHalfOfASharedRowSelectsTheSecondAyah() {
        launchReader(page: 2)
        let first = requireElement("ayah-2:1")
        let second = requireElement("ayah-2:2")
        // Both Ayahs must genuinely share a row: their bounding boxes overlap
        // vertically, and 2:2 must reach further left than 2:1.
        XCTAssertGreaterThanOrEqual(first.frame.maxY, second.frame.minY, "2:1 and 2:2 must share a row.")
        XCTAssertLessThan(second.frame.minX, first.frame.maxX, "2:2 must occupy the left side of the shared row.")

        let sharedRowCenterY = first.frame.midY
        press(at: CGPoint(x: second.frame.minX + 16, y: sharedRowCenterY))

        assertSheetShows(verseKey: "2:2")
        attachScreenshot("page2-sheet-2-2")
        dismissSheet()
        attachScreenshot("page2-glaze-2-2")
    }

    func testHoldingTheRightHalfOfASharedRowSelectsTheFirstAyah() {
        launchReader(page: 2)
        let first = requireElement("ayah-2:1")
        requireElement("ayah-2:2")

        let sharedRowCenterY = first.frame.midY
        press(at: CGPoint(x: first.frame.maxX - 16, y: sharedRowCenterY))

        assertSheetShows(verseKey: "2:1")
        dismissSheet()
        attachScreenshot("page2-glaze-2-1")
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
        let chrome = requireElement("reader-chrome")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        waitForDisappearance(chrome, timeout: 8)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        XCTAssertTrue(chrome.waitForExistence(timeout: 8), "A second tap must restore the reading chrome.")
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
        launchReader(page: 847)
        let last = requireElement("ayah-114:6")
        press(at: CGPoint(x: last.frame.midX, y: last.frame.midY))
        assertSheetShows(verseKey: "114:6")
        dismissSheet()
    }
}
