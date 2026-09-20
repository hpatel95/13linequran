//
//  QuranPageFrame.swift
//  QuranApp
//
//  The content rectangle terminates exactly at the inner border. The canvas
//  owns all thirteen row rules, including the lower edge of the final row.
//

import SwiftUI

public struct QuranPageFrame<Content: View>: View {
    public let pageNumber: Int
    public let surahName: String
    public let surahArabicName: String
    public let juzNumber: Int
    public let juzArabicName: String
    public let palette: ThemePalette
    public let onTap: () -> Void
    @ViewBuilder public let content: () -> Content

    public init(
        pageNumber: Int,
        surahName: String = "",
        surahArabicName: String = "",
        juzNumber: Int = 1,
        juzArabicName: String = "",
        palette: ThemePalette = AppColors.palette(for: .sepia),
        onTap: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.pageNumber = pageNumber
        self.surahName = surahName
        self.surahArabicName = surahArabicName
        self.juzNumber = juzNumber
        self.juzArabicName = juzArabicName
        self.palette = palette
        self.onTap = onTap
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 3) {
            header
            ZStack {
                Rectangle().fill(palette.paperAged)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTap)
                content().padding(3)
                Rectangle().strokeBorder(palette.borderSepia, lineWidth: 1)
                    .allowsHitTesting(false)
                InnerPageBorder()
                    .stroke(palette.saddleAmber.opacity(0.38), lineWidth: 0.5)
                    .padding(3)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 2)
        .background {
            palette.canvasVellum
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(juzArabicName.isEmpty ? "پارہ \(easternDigits(juzNumber))" : juzArabicName)
                .font(AppTypography.mushafMetadata(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                Text(easternDigits(pageNumber)).font(AppTypography.mushafMetadata(size: 13))
                Text("— \(pageNumber)").font(.system(size: 10, weight: .medium))
            }
            .environment(\.layoutDirection, .leftToRight)
            Text(surahArabicName.isEmpty ? surahName : surahArabicName)
                .font(AppTypography.mushafMetadata(size: 12))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(palette.sepiaMuted)
        .environment(\.layoutDirection, .rightToLeft)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(pageNumber), \(surahName), Juz \(juzNumber)")
        .accessibilityHint("Show or hide reading controls")
        .accessibilityAddTraits(.isButton)
    }

    private func easternDigits(_ value: Int) -> String {
        let digits = Array("٠١٢٣٤٥٦٧٨٩")
        return String(String(value).map { character in
            character.wholeNumberValue.map { digits[$0] } ?? character
        })
    }
}

private struct InnerPageBorder: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            // Row 13 supplies the bottom rule; do not double-stroke it.
        }
    }
}
