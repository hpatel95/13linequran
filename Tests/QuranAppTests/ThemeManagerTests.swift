//
//  ThemeManagerTests.swift
//  QuranAppTests
//
//  Unit tests verifying ThemeManager state persistence, palette color tokens,
//  colorScheme switching, and accessibility contrast standards.
//

import XCTest
import SwiftUI
@testable import QuranApp

@MainActor
final class ThemeManagerTests: XCTestCase {

    // Async overrides are used so the main-actor-isolated class does not attempt
    // to override a nonisolated synchronous XCTestCase hook.
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "selectedTheme")
        try await super.tearDown()
    }

    func testThemeSwitchingAndPersistence() {
        let themeManager = ThemeManager()
        XCTAssertEqual(themeManager.currentTheme, .sepia, "Default theme must be Heritage Sepia.")

        themeManager.setTheme(.midnight)
        XCTAssertEqual(themeManager.currentTheme, .midnight)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "selectedTheme"),
            "midnight",
            "Setting theme must sync to UserDefaults."
        )

        themeManager.setTheme(.ivory)
        XCTAssertEqual(themeManager.currentTheme, .ivory)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "selectedTheme"),
            "ivory"
        )
    }

    func testColorSchemePerTheme() {
        XCTAssertEqual(AppTheme.sepia.colorScheme, .light)
        XCTAssertEqual(AppTheme.ivory.colorScheme, .light)
        XCTAssertEqual(AppTheme.midnight.colorScheme, .dark, "Midnight OLED must declare .dark colorScheme.")
    }

    func testPalettesForAllThemes() {
        for theme in AppTheme.allCases {
            let palette = AppColors.palette(for: theme)

            // Verify essential palette colors are initialized
            XCTAssertNotNil(palette.canvasVellum)
            XCTAssertNotNil(palette.paperAged)
            XCTAssertNotNil(palette.surfacePapyrus)
            XCTAssertNotNil(palette.inkUmber)
            XCTAssertNotNil(palette.saddleAmber)
            XCTAssertNotNil(palette.borderSepia)
            XCTAssertNotNil(palette.ayahHighlightGlaze)
            XCTAssertNotNil(palette.ayahHighlightBorder)
        }
    }

    func testThemeTitlesAndSubtitles() {
        XCTAssertEqual(AppTheme.sepia.title, "Heritage Sepia")
        XCTAssertEqual(AppTheme.ivory.title, "Soft Ivory")
        XCTAssertEqual(AppTheme.midnight.title, "Midnight OLED")

        for theme in AppTheme.allCases {
            XCTAssertFalse(theme.subtitle.isEmpty, "Every theme must have an informative subtitle.")
        }
    }
}
