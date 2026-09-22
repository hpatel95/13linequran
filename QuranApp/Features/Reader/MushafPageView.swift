//
//  MushafPageView.swift
//  QuranApp
//
//  Enhanced native vector 13-line Mushaf page view with authentic physical editorial
//  decorations: 13 crisp ruling lines, alternating outer margin gutters, calligraphic
//  Ruku Ain badges with stacked numerals, Surah cartouches, and illuminated frontispieces.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI

@MainActor
public struct MushafPageView: View {
    public let pageNumber: Int
    public let lines: [MushafLine]
    public let surahName: String
    public let surahArabicName: String
    public let juzNumber: Int
    public let juzArabicName: String
    public let surahMetadata: [Int: Surah]
    public let selectedVerseKey: String?
    public let palette: ThemePalette
    public let onSelectAyah: ((Int, Int) -> Void)?
    public let onToggleChrome: () -> Void
    @Environment(\.displayScale) private var displayScale

    private static let marginWidth: CGFloat = 34.0

    public init(
        pageNumber: Int,
        lines: [MushafLine],
        surahName: String = "",
        surahArabicName: String = "",
        juzNumber: Int = 1,
        juzArabicName: String = "",
        surahMetadata: [Int: Surah] = [:],
        selectedVerseKey: String? = nil,
        palette: ThemePalette = AppColors.palette(for: .sepia),
        onSelectAyah: ((Int, Int) -> Void)? = nil,
        onToggleChrome: @escaping () -> Void = {}
    ) {
        self.pageNumber = pageNumber
        self.lines = lines
        self.surahName = surahName
        self.surahArabicName = surahArabicName
        self.juzNumber = juzNumber
        self.juzArabicName = juzArabicName
        self.surahMetadata = surahMetadata
        self.selectedVerseKey = selectedVerseKey
        self.palette = palette
        self.onSelectAyah = onSelectAyah
        self.onToggleChrome = onToggleChrome
    }

    public var body: some View {
        let editorialMarks = MushafEditorialService.shared.marks(for: pageNumber)
        let isOuterMarginOnRight = MushafEditorialService.isOuterMarginOnRight(pageNumber: pageNumber)

        QuranPageFrame(
            pageNumber: pageNumber,
            surahName: surahName,
            surahArabicName: surahArabicName,
            juzNumber: juzNumber,
            juzArabicName: juzArabicName,
            palette: palette,
            onTap: onToggleChrome
        ) {
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                let totalHeight = proxy.size.height
                let marginW = Self.marginWidth
                let textWidth = max(0, totalWidth - marginW)
                let textGrid = MushafPageGrid(
                    size: CGSize(width: textWidth, height: totalHeight),
                    displayScale: displayScale
                )

                let textOffsetX: CGFloat = isOuterMarginOnRight ? 0 : marginW
                let marginOffsetX: CGFloat = isOuterMarginOnRight ? textWidth : 0

                ZStack(alignment: .topLeading) {
                    // MARK: - Central 13-Line Text Canvas
                    ZStack(alignment: .topLeading) {
                        MushafTextCanvas(
                            lines: lines,
                            grid: textGrid,
                            selectedVerseKey: selectedVerseKey,
                            palette: palette,
                            onTap: onToggleChrome,
                            onSelectAyah: { word in onSelectAyah?(word.surah, word.ayah) }
                        )

                        // Surah Cartouche Overlays
                        ForEach(lines) { line in
                            if line.lineType == .surahName {
                                let rect = textGrid.rowRect(line.lineNumber)
                                MushafLineView(
                                    line: line,
                                    surah: line.surahId.flatMap { surahMetadata[$0] },
                                    palette: palette
                                )
                                .frame(width: rect.width - 2, height: max(0, rect.height - 2))
                                .position(x: rect.midX, y: rect.midY)
                                .allowsHitTesting(false)
                            }
                        }

                        // Frontispiece Lower Decorative Panel (Rows 9–13 on Pages 1 and 2)
                        if editorialMarks.hasFrontispiece && (pageNumber == 1 || pageNumber == 2) {
                            let topY = textGrid.boundary(8)
                            let bottomY = textGrid.boundary(13)
                            let panelHeight = max(0, bottomY - topY - 2)
                            MushafLowerPanelDecoration(palette: palette)
                                .frame(width: textWidth - 4, height: panelHeight)
                                .position(x: textWidth / 2, y: topY + panelHeight / 2 + 1)
                        }

                        if lines.isEmpty {
                            ProgressView()
                                .tint(palette.saddleAmber)
                                .position(x: textWidth / 2, y: totalHeight / 2)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: textWidth, height: totalHeight)
                    .offset(x: textOffsetX, y: 0)

                    // MARK: - Vertical Dividing Rule (Jadwal)
                    Rectangle()
                        .fill(palette.borderSepia.opacity(0.45))
                        .frame(width: 0.75, height: totalHeight)
                        .offset(x: isOuterMarginOnRight ? textWidth : marginW, y: 0)
                        .allowsHitTesting(false)

                    // MARK: - Outer Margin Editorial Badges
                    ZStack(alignment: .topLeading) {
                        // Margin tap target
                        Color.clear
                            .frame(width: marginW, height: totalHeight)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onToggleChrome)

                        // Margin Ruku Ain Badges
                        ForEach(editorialMarks.rukuMarks) { ruku in
                            let rowMidY = textGrid.rowRect(ruku.lineNumber).midY
                            MarginRukuView(rukuMark: ruku, palette: palette)
                                .position(x: marginW / 2, y: rowMidY)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: marginW, height: totalHeight)
                    .offset(x: marginOffsetX, y: 0)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .transaction { $0.animation = nil }
        }
        .accessibilityIdentifier("mushaf-page-\(pageNumber)")
    }
}
