//
//  ThemeManager.swift
//  QuranApp
//
//  Observable theme manager coordinating visual reading palettes:
//  Heritage Sepia, Soft Ivory Parchment, and Midnight OLED Dark.
//

import SwiftUI
import Observation

public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case sepia = "sepia"
    case ivory = "ivory"
    case midnight = "midnight"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sepia: return "Heritage Sepia"
        case .ivory: return "Soft Ivory"
        case .midnight: return "Midnight OLED"
        }
    }

    public var subtitle: String {
        switch self {
        case .sepia: return "Classical tooled leather & aged parchment"
        case .ivory: return "Gentle daylight paper & warm tones"
        case .midnight: return "Pure black for night reading with zero eye strain"
        }
    }

    public var colorScheme: ColorScheme {
        switch self {
        case .sepia, .ivory: return .light
        case .midnight: return .dark
        }
    }
}

public struct ThemePalette: Sendable {
    public let canvasVellum: Color
    public let paperAged: Color
    public let surfacePapyrus: Color
    public let sheetSurface: Color
    public let inkUmber: Color
    public let sepiaMuted: Color
    public let saddleAmber: Color
    public let primaryDeepAmber: Color
    public let borderSepia: Color
    public let ayahHighlightGlaze: Color
    public let ayahHighlightBorder: Color

    public init(
        canvasVellum: Color,
        paperAged: Color,
        surfacePapyrus: Color,
        sheetSurface: Color,
        inkUmber: Color,
        sepiaMuted: Color,
        saddleAmber: Color,
        primaryDeepAmber: Color,
        borderSepia: Color,
        ayahHighlightGlaze: Color,
        ayahHighlightBorder: Color
    ) {
        self.canvasVellum = canvasVellum
        self.paperAged = paperAged
        self.surfacePapyrus = surfacePapyrus
        self.sheetSurface = sheetSurface
        self.inkUmber = inkUmber
        self.sepiaMuted = sepiaMuted
        self.saddleAmber = saddleAmber
        self.primaryDeepAmber = primaryDeepAmber
        self.borderSepia = borderSepia
        self.ayahHighlightGlaze = ayahHighlightGlaze
        self.ayahHighlightBorder = ayahHighlightBorder
    }
}

@Observable
@MainActor
public final class ThemeManager {
    public var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }

    public init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .sepia
        }
    }

    public var colors: ThemePalette {
        AppColors.palette(for: currentTheme)
    }

    public func setTheme(_ theme: AppTheme) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            self.currentTheme = theme
        }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
