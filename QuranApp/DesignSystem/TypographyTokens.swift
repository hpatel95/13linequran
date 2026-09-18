//
//  TypographyTokens.swift
//  QuranApp
//
//  Typographic tokens extracted from Stitch design system.
//  Combines Apple system fonts with classical editorial serif and Indo-Pak Arabic calligraphy.
//

import SwiftUI

public enum AppTypography {
    // MARK: - Editorial Titles (Serif / Newsreader / Apple New York style)
    public static let headlineLarge = Font.system(.title, design: .serif).weight(.medium)
    public static let headlineMedium = Font.system(.title2, design: .serif).weight(.medium)
    public static let headlineSmall = Font.system(.headline, design: .serif).weight(.semibold)
    
    // MARK: - Translation & Body Text
    public static let bodyLarge = Font.system(.body, design: .serif)
    public static let bodyMedium = Font.system(.subheadline, design: .serif)
    
    // MARK: - UI Labels & Metadata (Apple SF Pro Sans)
    public static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    public static let labelSmall = Font.system(size: 11, weight: .semibold, design: .default)
    public static let caption = Font.system(size: 10, weight: .semibold, design: .default)
    
    // MARK: - Arabic Calligraphy Helpers
    public static func arabicCalligraphy(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Falls back to system Arabic font (Geeza Pro / Noto Naskh) if custom font is not bundled
        return Font.custom("NotoNaskhArabic", size: size).weight(weight)
    }

    // MARK: - Compatibility Aliases & Semantic Helpers
    public static let headline = headlineSmall
    public static let body = bodyMedium
    public static let surahHeader = arabicCalligraphy(size: 17, weight: .bold)
    public static let arabic13Line = arabicCalligraphy(size: 17, weight: .medium)
    public static let pageNumber = Font.system(size: 11, weight: .semibold, design: .default)
    public static let englishTranslation = Font.system(.body, design: .serif)
    public static let bodyEnglish = englishTranslation
}
