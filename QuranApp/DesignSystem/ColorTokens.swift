//
//  ColorTokens.swift
//  QuranApp
//
//  Extracted directly from the Stitch "Heritage Sepia & Tooled Leather" design system.
//  Matching the classical South Asian 13-line lithograph and Apple Books editorial standards.
//

import SwiftUI

public enum AppColors {
    // MARK: - Canvas & Paper Surfaces
    /// The main warm vellum background (#F3EDE0) - chassis and outer canvas
    public static let canvasVellum = Color(hex: 0xF3EDE0)
    
    /// The interior 13-line lithograph page surface (#FAF6EE) - gentle on the eyes
    public static let paperAged = Color(hex: 0xFAF6EE)
    
    /// Elevated card and capsule pill surface (#EAE3D3)
    public static let surfacePapyrus = Color(hex: 0xEAE3D3)
    
    /// Pure sheet surface (#FFFFFF) for high-contrast modal overlays
    public static let sheetSurface = Color(hex: 0xFFFFFF)

    // MARK: - Ink & Typography
    /// Deep dark umber ink (#2B2620) - lamp-black lithographic calligraphy
    public static let inkUmber = Color(hex: 0x2B2620)
    
    /// Secondary muted text (#6E6459) - English translation and verse metadata
    public static let sepiaMuted = Color(hex: 0x6E6459)

    // MARK: - Sacred Accents & Borders
    /// Primary saddle amber / warm camel gold (#9E6B38) - active buttons, markers, cartouche
    public static let saddleAmber = Color(hex: 0x9E6B38)
    
    /// Deep lithographic primary amber (#825322) for prominent page numbers & calligraphy
    public static let primaryDeepAmber = Color(hex: 0x825322)

    /// Soft hairline divider and border (#DFD7C7)
    public static let borderSepia = Color(hex: 0xDFD7C7)

    // MARK: - Revelation Badges (Stitch Design)
    /// Medinan badge slate-teal text (#28647D)
    public static let medinanTeal = Color(hex: 0x28647D)

    /// Medinan badge parchment background (#EEE0D2 at 50% opacity)
    public static let medinanBadgeFill = Color(hex: 0xEEE0D2).opacity(0.50)

    // MARK: - Interactive Highlights
    /// Ayah selection highlight glaze (rgba(158, 107, 56, 0.20))
    public static let ayahHighlightGlaze = Color(red: 158 / 255.0, green: 107 / 255.0, blue: 56 / 255.0, opacity: 0.20)
    
    /// Hairline border surrounding active ayah bounds (#9E6B38 at 80% opacity)
    public static let ayahHighlightBorder = Color(hex: 0x9E6B38).opacity(0.80)

    // MARK: - Dynamic Theme Palettes
    public static func palette(for theme: AppTheme) -> ThemePalette {
        switch theme {
        case .sepia:
            return ThemePalette(
                canvasVellum: Color(hex: 0xF3EDE0),
                paperAged: Color(hex: 0xFAF6EE),
                surfacePapyrus: Color(hex: 0xEAE3D3),
                sheetSurface: Color(hex: 0xFFFFFF),
                inkUmber: Color(hex: 0x2B2620),
                sepiaMuted: Color(hex: 0x6E6459),
                saddleAmber: Color(hex: 0x9E6B38),
                primaryDeepAmber: Color(hex: 0x825322),
                borderSepia: Color(hex: 0xDFD7C7),
                ayahHighlightGlaze: Color(red: 158 / 255.0, green: 107 / 255.0, blue: 56 / 255.0, opacity: 0.20),
                ayahHighlightBorder: Color(hex: 0x9E6B38).opacity(0.80)
            )

        case .ivory:
            return ThemePalette(
                canvasVellum: Color(hex: 0xF7F4EC),
                paperAged: Color(hex: 0xFCFAF5),
                surfacePapyrus: Color(hex: 0xF0EBE0),
                sheetSurface: Color(hex: 0xFFFFFF),
                inkUmber: Color(hex: 0x262422),
                sepiaMuted: Color(hex: 0x736D65),
                saddleAmber: Color(hex: 0xA6743A),
                primaryDeepAmber: Color(hex: 0x8E5E28),
                borderSepia: Color(hex: 0xE5DFD3),
                ayahHighlightGlaze: Color(red: 166 / 255.0, green: 116 / 255.0, blue: 58 / 255.0, opacity: 0.20),
                ayahHighlightBorder: Color(hex: 0xA6743A).opacity(0.80)
            )

        case .midnight:
            return ThemePalette(
                canvasVellum: Color(hex: 0x000000),
                paperAged: Color(hex: 0x0D0D0D),
                surfacePapyrus: Color(hex: 0x1A1A1A),
                sheetSurface: Color(hex: 0x141414),
                inkUmber: Color(hex: 0xF5EBD7),
                sepiaMuted: Color(hex: 0x9E978C),
                saddleAmber: Color(hex: 0xD4A054),
                primaryDeepAmber: Color(hex: 0xE0B066),
                borderSepia: Color(hex: 0x2A2722),
                ayahHighlightGlaze: Color(red: 212 / 255.0, green: 160 / 255.0, blue: 84 / 255.0, opacity: 0.30),
                ayahHighlightBorder: Color(hex: 0xD4A054).opacity(0.90)
            )
        }
    }
}


// MARK: - Color Hex Initializer Helper
extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
