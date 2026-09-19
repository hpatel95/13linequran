//
//  QuranPageFrame.swift
//  QuranApp
//
//  Classical lithograph ornamental page container with header, border, and footer.
//

import SwiftUI

public struct QuranPageFrame<Content: View>: View {
    public let pageNumber: Int
    public let surahName: String
    public let surahArabicName: String
    public let juzNumber: Int
    public let juzArabicName: String
    @ViewBuilder public let content: () -> Content
    
    public init(
        pageNumber: Int,
        surahName: String = "",
        surahArabicName: String = "",
        juzNumber: Int = 1,
        juzArabicName: String = "",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.pageNumber = pageNumber
        self.surahName = surahName
        self.surahArabicName = surahArabicName
        self.juzNumber = juzNumber
        self.juzArabicName = juzArabicName
        self.content = content
    }

    private func toEasternArabic(_ num: Int) -> String {
        let digits = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩"
        ]
        return String(num).map { digits[String($0)] ?? String($0) }.joined()
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Authentic Lithograph Header (Juz • Page • Surah)
            HStack(alignment: .center) {
                // Right (RTL leading): Juz info in Arabic
                Text(juzArabicName.isEmpty ? "پارہ \(toEasternArabic(juzNumber))" : juzArabicName)
                    .font(AppTypography.arabicCalligraphy(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.sepiaMuted)
                    .lineLimit(1)

                Spacer()

                // Center: Eastern Arabic & Western page numbers
                HStack(spacing: 4) {
                    Text(toEasternArabic(pageNumber))
                        .font(AppTypography.arabicCalligraphy(size: 13, weight: .bold))
                    Text("—")
                        .font(.system(size: 10))
                    Text("\(pageNumber)")
                        .font(.system(size: 11, weight: .semibold, design: .default))
                }
                .foregroundStyle(AppColors.sepiaMuted)

                Spacer()

                // Left (RTL trailing): Surah Arabic Name
                Text(surahArabicName.isEmpty ? surahName : surahArabicName)
                    .font(AppTypography.arabicCalligraphy(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.sepiaMuted)
                    .lineLimit(1)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal, 14)
            .padding(.top, 4)

            // 13-Line Page Lithograph Box
            ZStack {
                // Page background
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.paperAged)
                    .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)

                // Outer hairline border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.borderSepia, lineWidth: 1.5)

                // Inner fine decorative line
                RoundedRectangle(cornerRadius: 4)
                    .stroke(AppColors.saddleAmber.opacity(0.35), lineWidth: 0.75)
                    .padding(2.5)

                // 13 Lines Content
                VStack(spacing: 0) {
                    content()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
            }
            .padding(.horizontal, 8)

            // Subtle Footer
            Spacer().frame(height: 2)
        }
        .background(AppColors.canvasVellum)
    }
}
