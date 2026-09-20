//
//  IslamicBanner.swift
//  QuranApp
//
//  A row-sized lithograph cartouche, never an extra minimum-height row.
//

import SwiftUI

public struct IslamicBanner: View {
    public let surahNumber: Int
    public let arabicName: String
    public let revelationType: String?
    public let totalVerses: Int
    public let palette: ThemePalette

    public init(
        surahNumber: Int, arabicName: String, revelationType: String? = nil,
        totalVerses: Int = 0, palette: ThemePalette = AppColors.palette(for: .sepia)
    ) {
        self.surahNumber = surahNumber
        self.arabicName = arabicName
        self.revelationType = revelationType
        self.totalVerses = totalVerses
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.height / 42)
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(palette.surfacePapyrus)
                RoundedRectangle(cornerRadius: 3).strokeBorder(palette.borderSepia, lineWidth: 1)
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(palette.saddleAmber.opacity(0.45), lineWidth: 0.5)
                    .padding(2.5)

                HStack(spacing: 4) {
                    Text(totalVerses > 0 ? "آيَاتُهَا \(easternDigits(totalVerses))" : "")
                        .font(AppTypography.mushafMetadata(size: 12 * scale))
                        .foregroundStyle(palette.sepiaMuted)
                        .frame(width: proxy.size.width * 0.21)
                    HStack(spacing: 5) {
                        Text(title)
                            .font(AppTypography.mushafMetadata(size: 17 * scale))
                            .foregroundStyle(palette.inkUmber)
                        if !revelationArabic.isEmpty {
                            Text(revelationArabic)
                                .font(AppTypography.mushafMetadata(size: 11 * scale))
                                .foregroundStyle(palette.saddleAmber)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Text("(\(easternDigits(surahNumber)))")
                        .font(AppTypography.mushafMetadata(size: 12 * scale))
                        .foregroundStyle(palette.sepiaMuted)
                        .frame(width: proxy.size.width * 0.15)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.horizontal, 6)
            }
        }
    }

    private var title: String {
        let clean = arabicName.replacingOccurrences(of: "سُورَةُ", with: "")
            .replacingOccurrences(of: "سُورَة", with: "")
            .trimmingCharacters(in: .whitespaces)
        return "سُورَةُ \(clean.isEmpty ? easternDigits(surahNumber) : clean)"
    }

    private var revelationArabic: String {
        let type = revelationType?.lowercased() ?? ""
        if type.contains("meccan") || type.contains("makki") { return "مَكِّيَّةٌ" }
        if type.contains("medinan") || type.contains("madani") { return "مَدَنِيَّةٌ" }
        return ""
    }

    private func easternDigits(_ value: Int) -> String {
        let digits = Array("٠١٢٣٤٥٦٧٨٩")
        return String(String(value).map { character in
            character.wholeNumberValue.map { digits[$0] } ?? character
        })
    }
}
