//
//  MarginRukuView.swift
//  QuranApp
//
//  The classical calligraphic Ain symbol (ع) rendered in the outer margin
//  at the exact line where a Ruku concludes. Displays three stacked eastern Arabic numerals:
//    - Top: Ruku sequence number within the Surah
//    - Center/Belly: Total number of Ayahs in this Ruku
//    - Bottom: Cumulative Ruku sequence number within the Juz
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI

public struct MarginRukuView: View {
    public let rukuMark: RukuMark
    public let palette: ThemePalette

    public init(rukuMark: RukuMark, palette: ThemePalette = AppColors.palette(for: .sepia)) {
        self.rukuMark = rukuMark
        self.palette = palette
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top: Ruku number in Surah (e.g. ۱, ۲)
            Text(AppTypography.easternArabicDigits(rukuMark.rukuInSurah))
                .font(AppTypography.mushafMetadata(size: 10))
                .fontWeight(.bold)
                .foregroundStyle(palette.saddleAmber)
                .lineLimit(1)

            // Center: Calligraphic Ain with Ayah count in belly
            ZStack {
                Text("ع")
                    .font(AppTypography.arabicCalligraphy(size: 24, weight: .bold))
                    .foregroundStyle(palette.inkUmber)

                // Middle number: Total Ayahs in this Ruku (e.g. ۷, ۱۳)
                Text(AppTypography.easternArabicDigits(rukuMark.ayahsInRuku))
                    .font(AppTypography.mushafMetadata(size: 9))
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.inkUmber)
                    .offset(x: -1, y: 1)
            }
            .frame(height: 20)

            // Bottom: Cumulative Ruku in Juz (e.g. ۲, ۳)
            Text(AppTypography.easternArabicDigits(rukuMark.rukuInJuz))
                .font(AppTypography.mushafMetadata(size: 10))
                .fontWeight(.medium)
                .foregroundStyle(palette.sepiaMuted)
                .lineLimit(1)
        }
        .frame(width: 26)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Ruku \(rukuMark.rukuInSurah) of Surah, \(rukuMark.ayahsInRuku) verses, Ruku \(rukuMark.rukuInJuz) of Juz"
        )
    }
}
