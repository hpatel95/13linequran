//
//  MushafLineView.swift
//  QuranApp
//
//  Renders an individual line within the 13-line physical Mushaf layout.
//

import SwiftUI

public struct MushafLineView: View {
    public let line: MushafLine
    public let surahNameArabic: String?
    public let surahNameEnglish: String?

    public init(
        line: MushafLine,
        surahNameArabic: String? = nil,
        surahNameEnglish: String? = nil
    ) {
        self.line = line
        self.surahNameArabic = surahNameArabic
        self.surahNameEnglish = surahNameEnglish
    }

    public var body: some View {
        Group {
            switch line.lineType {
            case .surahName:
                IslamicBanner(
                    surahNumber: line.surahId ?? 1,
                    arabicName: surahNameArabic ?? "",
                    englishName: surahNameEnglish ?? ""
                )
                .padding(.horizontal, 4)

            case .bismillah:
                Text("﷽")
                    .font(AppTypography.arabic13Line)
                    .foregroundStyle(AppColors.saddleAmber)
                    .frame(maxWidth: .infinity, alignment: .center)

            case .ayahText:
                if line.isCentered {
                    Text(line.textIndopak)
                        .font(AppTypography.arabic13Line)
                        .foregroundStyle(AppColors.inkUmber)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .environment(\.layoutDirection, .rightToLeft)
                } else {
                    Text(line.textIndopak)
                        .font(AppTypography.arabic13Line)
                        .foregroundStyle(AppColors.inkUmber)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }
            }
        }
        .frame(height: 38)
    }
}
