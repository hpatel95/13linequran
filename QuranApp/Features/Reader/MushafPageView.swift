//
//  MushafPageView.swift
//  QuranApp
//
//  A single ruled/text canvas with SwiftUI decorations positioned in the exact
//  same thirteen slots. No VStack distribution or per-word layout is involved.
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
        QuranPageFrame(
            pageNumber: pageNumber, surahName: surahName, surahArabicName: surahArabicName,
            juzNumber: juzNumber, juzArabicName: juzArabicName,
            palette: palette, onTap: onToggleChrome
        ) {
            GeometryReader { proxy in
                let grid = MushafPageGrid(size: proxy.size, displayScale: displayScale)
                MushafTextCanvas(
                    lines: lines, grid: grid, selectedVerseKey: selectedVerseKey, palette: palette,
                    onTap: onToggleChrome,
                    onSelectAyah: { word in onSelectAyah?(word.surah, word.ayah) }
                )
                .overlay(alignment: .topLeading) {
                    ForEach(lines) { line in
                        if line.lineType == .surahName {
                            let rect = grid.rowRect(line.lineNumber)
                            MushafLineView(line: line, surah: line.surahId.flatMap { surahMetadata[$0] }, palette: palette)
                                .frame(width: rect.width - 2, height: max(0, rect.height - 2))
                                .position(x: rect.midX, y: rect.midY)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .overlay {
                    if lines.isEmpty {
                        ProgressView().tint(palette.saddleAmber).allowsHitTesting(false)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            // Do not interpolate a new page grid while keeping an old hit map.
            // Chrome can spring independently; typography commits atomically.
            .transaction { $0.animation = nil }
        }
        .accessibilityIdentifier("mushaf-page-\(pageNumber)")
    }
}
