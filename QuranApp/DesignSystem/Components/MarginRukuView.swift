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
        VStack(spacing: 1) {
            // Top: Ruku number in Surah (e.g. ۱, ۲)
            Text(AppTypography.easternArabicDigits(rukuMark.rukuInSurah))
                .font(.system(size: 9.5, weight: .bold, design: .serif))
                .foregroundStyle(palette.saddleAmber)
                .lineLimit(1)

            // Center: Calligraphic Ain with Ayah count in belly
            ZStack {
                Text("ع")
                    .font(AppTypography.arabicCalligraphy(size: 18, weight: .bold))
                    .foregroundStyle(palette.inkUmber)

                // Middle number: Total Ayahs in this Ruku (e.g. ۷, ۱۳)
                Text(AppTypography.easternArabicDigits(rukuMark.ayahsInRuku))
                    .font(.system(size: 8, weight: .bold, design: .serif))
                    .foregroundStyle(palette.inkUmber)
                    .offset(x: -0.5, y: 1)
            }
            .frame(width: 24, height: 18)

            // Bottom: Cumulative Ruku in Juz (e.g. ۲, ۳)
            Text(AppTypography.easternArabicDigits(rukuMark.rukuInJuz))
                .font(.system(size: 9.5, weight: .bold, design: .serif))
                .foregroundStyle(palette.sepiaMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(palette.surfacePapyrus.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(palette.saddleAmber.opacity(0.35), lineWidth: 0.5)
        )
        .frame(width: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Ruku \(rukuMark.rukuInSurah) of Surah, \(rukuMark.ayahsInRuku) verses, Ruku \(rukuMark.rukuInJuz) of Juz"
        )
    }
}
