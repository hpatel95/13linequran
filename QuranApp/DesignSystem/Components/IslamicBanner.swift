//
//  IslamicBanner.swift
//  QuranApp
//
//  Classical Surah header cartouche inspired by South Asian lithographic borders
//  and the Stitch Heritage Sepia design system tokens.
//

import SwiftUI

public struct IslamicBanner: View {
    public let surahNumber: Int
    public let arabicName: String
    public let revelationType: String?
    public let totalVerses: Int

    public init(
        surahNumber: Int,
        arabicName: String,
        revelationType: String? = nil,
        totalVerses: Int = 0
    ) {
        self.surahNumber = surahNumber
        self.arabicName = arabicName
        self.revelationType = revelationType
        self.totalVerses = totalVerses
    }

    private var easternSurahNumber: String {
        toEasternArabic(surahNumber)
    }

    private var easternVerses: String {
        toEasternArabic(totalVerses)
    }

    private var revelationArabic: String {
        guard let rev = revelationType?.lowercased() else { return "" }
        if rev.contains("meccan") || rev.contains("makki") {
            return "مَكِّيَّةٌ"
        } else if rev.contains("medinan") || rev.contains("madani") {
            return "مَدَنِيَّةٌ"
        }
        return ""
    }

    private func toEasternArabic(_ num: Int) -> String {
        let digits = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩"
        ]
        return String(num).map { digits[String($0)] ?? String($0) }.joined()
    }

    public var body: some View {
        ZStack {
            // Cartouche ornamental background
            RoundedRectangle(cornerRadius: 6)
                .fill(AppColors.surfacePapyrus)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppColors.borderSepia, lineWidth: 1.5)
                )

            // Inner fine decorative line
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.saddleAmber.opacity(0.5), lineWidth: 0.75)
                .padding(3)

            // Classical Lithograph Surah Cartouche Content (RTL)
            HStack(alignment: .center) {
                // Right side (RTL leading): Verses count
                if totalVerses > 0 {
                    Text("آيَاتُهَا \(easternVerses)")
                        .font(AppTypography.arabicCalligraphy(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.sepiaMuted)
                } else {
                    Spacer().frame(width: 40)
                }

                Spacer()

                // Center: Surah Name + Revelation Type
                let cleanName = arabicName.replacingOccurrences(of: "سُورَةُ", with: "")
                    .replacingOccurrences(of: "سُورَة", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let title = cleanName.isEmpty ? "سُورَةُ \(surahNumber)" : "سُورَةُ \(cleanName)"

                HStack(spacing: 8) {
                    Text(title)
                        .font(AppTypography.arabicCalligraphy(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.inkUmber)

                    if !revelationArabic.isEmpty {
                        Text(revelationArabic)
                            .font(AppTypography.arabicCalligraphy(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.saddleAmber)
                    }
                }
                .lineLimit(1)

                Spacer()

                // Left side (RTL trailing): Surah Number
                Text("(\(easternSurahNumber))")
                    .font(AppTypography.arabicCalligraphy(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.sepiaMuted)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal, 10)
        }
        .frame(minHeight: 40)
    }
}
