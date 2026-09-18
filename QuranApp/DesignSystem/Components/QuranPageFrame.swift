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
    public let juzNumber: Int
    @ViewBuilder public let content: () -> Content

    public init(
        pageNumber: Int,
        surahName: String = "",
        juzNumber: Int = 1,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.pageNumber = pageNumber
        self.surahName = surahName
        self.juzNumber = juzNumber
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Page Header
            HStack {
                Text("Juz \(juzNumber)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)

                Spacer()

                if !surahName.isEmpty {
                    Text(surahName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.sepiaMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // 13-Line Page Lithograph Box
            ZStack {
                // Page background
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.paperAged)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)

                // Outer hairline border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.borderSepia, lineWidth: 1.5)

                // Inner fine decorative line
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.saddleAmber.opacity(0.35), lineWidth: 0.75)
                    .padding(3)

                // 13 Lines Content
                VStack(spacing: 0) {
                    content()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .padding(.horizontal, 12)

            // Page Footer
            HStack {
                Spacer()
                Text("— \(pageNumber) —")
                    .font(AppTypography.pageNumber)
                    .foregroundStyle(AppColors.sepiaMuted)
                Spacer()
            }
            .padding(.bottom, 6)
        }
        .background(AppColors.canvasVellum)
    }
}
