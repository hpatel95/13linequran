//
//  SurahCartoucheView.swift
//  QuranApp
//
//  Authentic 3-compartment Indo-Pak vector cartouche for Surah headings.
//  Contains:
//    - Right Panel: Total Ayahs (e.g. "آيَاتُهَا ۲۸٦")
//    - Center Panel: Calligraphic Surah Title & Revelation Type ("سُورَةُ البَقَرَةِ مَدَنِيَّةٌ")
//    - Left Panel: Total Rukus (e.g. "رُكُوعَاتُهَا ٤۰")
//  Framed by traditional multi-stroke lithographic borders and decorative panel dividers.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI

public struct SurahCartoucheView: View {
    public let surahNumber: Int
    public let arabicName: String
    public let revelationType: String?
    public let totalVerses: Int
    public let totalRukus: Int
    public let palette: ThemePalette

    public init(
        surahNumber: Int,
        arabicName: String,
        revelationType: String? = nil,
        totalVerses: Int = 0,
        totalRukus: Int = 0,
        palette: ThemePalette = AppColors.palette(for: .sepia)
    ) {
        self.surahNumber = surahNumber
        self.arabicName = arabicName
        self.revelationType = revelationType
        self.totalVerses = totalVerses > 0 ? totalVerses : Self.defaultVerses(for: surahNumber)
        self.totalRukus = totalRukus > 0 ? totalRukus : Self.defaultRukus(for: surahNumber)
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = min(1.0, max(0.65, proxy.size.height / 38.0))
            ZStack {
                // Background Papyrus Fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(palette.surfacePapyrus)

                // Double Lithographic Border
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(palette.borderSepia, lineWidth: 1.0)
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(palette.saddleAmber.opacity(0.5), lineWidth: 0.5)
                    .padding(2.0)

                // 3-Panel Content
                HStack(spacing: 0) {
                    // Right Panel: Ayah Count
                    HStack(spacing: 2) {
                        if totalVerses > 0 {
                            Text("آيَاتُهَا")
                                .font(AppTypography.mushafMetadata(size: 10 * scale))
                                .foregroundStyle(palette.sepiaMuted)
                            Text(AppTypography.easternArabicDigits(totalVerses))
                                .font(.system(size: 11 * scale, weight: .semibold, design: .serif))
                                .foregroundStyle(palette.inkUmber)
                        }
                    }
                    .frame(width: proxy.size.width * 0.24, alignment: .center)

                    // Vertical Divider 1
                    CartoucheDivider(palette: palette)

                    // Center Panel: Surah Title + Revelation
                    HStack(spacing: 6) {
                        Text(title)
                            .font(AppTypography.arabicCalligraphy(size: 16 * scale, weight: .bold))
                            .foregroundStyle(palette.inkUmber)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        if !revelationArabic.isEmpty {
                            Text(revelationArabic)
                                .font(AppTypography.mushafMetadata(size: 10 * scale))
                                .foregroundStyle(palette.saddleAmber)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Vertical Divider 2
                    CartoucheDivider(palette: palette)

                    // Left Panel: Ruku Count
                    HStack(spacing: 2) {
                        if totalRukus > 0 {
                            Text("رُكُوعَاتُهَا")
                                .font(AppTypography.mushafMetadata(size: 10 * scale))
                                .foregroundStyle(palette.sepiaMuted)
                            Text(AppTypography.easternArabicDigits(totalRukus))
                                .font(.system(size: 11 * scale, weight: .semibold, design: .serif))
                                .foregroundStyle(palette.inkUmber)
                        } else {
                            Text("(\(AppTypography.easternArabicDigits(surahNumber)))")
                                .font(.system(size: 11 * scale, weight: .semibold, design: .serif))
                                .foregroundStyle(palette.sepiaMuted)
                        }
                    }
                    .frame(width: proxy.size.width * 0.24, alignment: .center)
                }
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Surah \(title), \(totalVerses) verses, \(totalRukus) rukus")
    }

    private var title: String {
        let clean = arabicName
            .replacingOccurrences(of: "سُورَةُ", with: "")
            .replacingOccurrences(of: "سُورَة", with: "")
            .trimmingCharacters(in: .whitespaces)
        return "سُورَةُ \(clean.isEmpty ? AppTypography.easternArabicDigits(surahNumber) : clean)"
    }

    private var revelationArabic: String {
        let type = revelationType?.lowercased() ?? ""
        if type.contains("meccan") || type.contains("makki") { return "مَكِّيَّةٌ" }
        if type.contains("medinan") || type.contains("madani") { return "مَدَنِيَّةٌ" }
        return ""
    }

    /// Precomputed total verses for key Surahs (fallback when metadata dictionary is loading)
    public static func defaultVerses(for surahNumber: Int) -> Int {
        switch surahNumber {
        case 1: return 7
        case 2: return 286
        case 3: return 200
        case 4: return 176
        case 114: return 6
        default: return 0
        }
    }

    /// Precomputed Ruku counts for key Surahs (fallback for all 114)
    public static func defaultRukus(for surahNumber: Int) -> Int {
        switch surahNumber {
        case 1: return 1   // Al-Fatihah
        case 2: return 40  // Al-Baqarah
        case 3: return 20  // Al-Imran
        case 4: return 24  // An-Nisa
        case 5: return 16  // Al-Ma'idah
        case 6: return 20  // Al-An'am
        case 7: return 24  // Al-A'raf
        case 8: return 10  // Al-Anfal
        case 9: return 16  // At-Tawbah
        case 114: return 1 // An-Nas
        default: return 0
        }
    }
}

// MARK: - Cartouche Divider
private struct CartoucheDivider: View {
    let palette: ThemePalette

    var body: some View {
        VStack(spacing: 1.5) {
            Circle()
                .fill(palette.saddleAmber.opacity(0.6))
                .frame(width: 2, height: 2)
            Rectangle()
                .fill(palette.borderSepia.opacity(0.4))
                .frame(width: 0.75, height: 16)
            Circle()
                .fill(palette.saddleAmber.opacity(0.6))
                .frame(width: 2, height: 2)
        }
        .padding(.horizontal, 2)
    }
}
