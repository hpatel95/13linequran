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
    public let englishName: String
    public let totalVerses: Int

    public init(
        surahNumber: Int,
        arabicName: String,
        englishName: String = "",
        totalVerses: Int = 0
    ) {
        self.surahNumber = surahNumber
        self.arabicName = arabicName
        self.englishName = englishName
        self.totalVerses = totalVerses
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

            // Inner double border effect
            RoundedRectangle(cornerRadius: 4)
                .stroke(AppColors.saddleAmber.opacity(0.4), lineWidth: 0.75)
                .padding(3)

            // Content
            HStack(spacing: 8) {
                if totalVerses > 0 {
                    Text("\(totalVerses) Verses")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.sepiaMuted)
                        .frame(minWidth: 60, alignment: .leading)
                } else {
                    Spacer()
                }

                Spacer()

                // Arabic Title
                Text(arabicName.isEmpty ? "سُورَة \(surahNumber)" : arabicName)
                    .font(AppTypography.surahHeader)
                    .foregroundStyle(AppColors.inkUmber)
                    .lineLimit(1)

                Spacer()

                if !englishName.isEmpty {
                    Text(englishName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.sepiaMuted)
                        .frame(minWidth: 60, alignment: .trailing)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 38)
    }
}
