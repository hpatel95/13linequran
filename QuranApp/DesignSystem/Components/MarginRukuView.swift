//
//  MarginRukuView.swift
//  QuranApp
//
//  The classical calligraphic Ain symbol (ع) rendered in the outer margin
//  at the exact line where a Ruku concludes. Displays three stacked eastern Arabic numerals:
//    - Top: Ruku sequence number within the Surah (رُكوع السورة)
//    - Center/Belly: Total number of Ayahs in this Ruku (عدد آيات الركوع), rendered with an
//      open knockout aperture so it never collides with or overlaps the calligraphic Ain stroke.
//    - Bottom: Cumulative Ruku sequence number within the Juz (ركوع البارة / الجزء)
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
        VStack(spacing: 1.0) {
            // Top: Ruku number in Surah (e.g. ۱, ۲)
            Text(AppTypography.easternArabicDigits(rukuMark.rukuInSurah))
                .font(.system(size: 8.5, weight: .bold, design: .serif))
                .foregroundStyle(palette.saddleAmber)
                .lineLimit(1)

            // Center: Calligraphic Ain with a clean knockout aperture for Ayah count
            ZStack {
                // Calligraphic Ain contour
                Text("ع")
                    .font(AppTypography.arabicCalligraphy(size: 19, weight: .bold))
                    .foregroundStyle(palette.inkUmber.opacity(0.85))
                    .offset(x: 1.5, y: -0.5)

                // Knockout counter ensuring 100% legibility of the verse count
                Circle()
                    .fill(palette.surfacePapyrus)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .strokeBorder(palette.saddleAmber.opacity(0.35), lineWidth: 0.5)
                    )
                    .offset(x: -1.0, y: 1.0)

                // Middle number: Total Ayahs in this Ruku (e.g. ۷, ۱۳)
                Text(AppTypography.easternArabicDigits(rukuMark.ayahsInRuku))
                    .font(.system(size: 7.5, weight: .bold, design: .serif))
                    .foregroundStyle(palette.inkUmber)
                    .offset(x: -1.0, y: 1.0)
            }
            .frame(width: 20, height: 18)

            // Bottom: Cumulative Ruku in Juz (e.g. ۲, ۳)
            Text(AppTypography.easternArabicDigits(rukuMark.rukuInJuz))
                .font(.system(size: 8.0, weight: .bold, design: .serif))
                .foregroundStyle(palette.sepiaMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 1.5)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(palette.surfacePapyrus.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .strokeBorder(palette.saddleAmber.opacity(0.4), lineWidth: 0.75)
        )
        .frame(width: 23)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Ruku \(rukuMark.rukuInSurah) of Surah, \(rukuMark.ayahsInRuku) verses, Ruku \(rukuMark.rukuInJuz) of Juz"
        )
    }
}
