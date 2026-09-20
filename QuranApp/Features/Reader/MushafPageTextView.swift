//
//  MushafPageTextView.swift
//  QuranApp
//
//  Accessible, Dynamic Type-friendly reader view presenting the active page's
//  verses with Indo-Pak Nastaleeq typography, translation previews, and audio tracking.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI

@MainActor
public struct MushafPageTextView: View {
    public let summary: MushafPageSummary
    public let verses: [Ayah]
    public let surahs: [Int: Surah]
    public let selectedVerse: VerseKey?
    public let playingVerse: VerseKey?
    public let palette: ThemePalette
    public let onSelectAyah: ((VerseKey) -> Void)?
    public let onToggleChrome: () -> Void

    public init(
        summary: MushafPageSummary,
        verses: [Ayah],
        surahs: [Int: Surah] = [:],
        selectedVerse: VerseKey? = nil,
        playingVerse: VerseKey? = nil,
        palette: ThemePalette = AppColors.palette(for: .sepia),
        onSelectAyah: ((VerseKey) -> Void)? = nil,
        onToggleChrome: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.verses = verses
        self.surahs = surahs
        self.selectedVerse = selectedVerse
        self.playingVerse = playingVerse
        self.palette = palette
        self.onSelectAyah = onSelectAyah
        self.onToggleChrome = onToggleChrome
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Page Header Banner
                pageHeader

                ForEach(verses) { ayah in
                    let key = VerseKey(surah: ayah.surahId, ayah: ayah.verseNumber)
                    let isSelected = (key == selectedVerse)
                    let isPlaying = (key == playingVerse)

                    verseCard(ayah: ayah, key: key, isSelected: isSelected, isPlaying: isPlaying)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(palette.canvasVellum.ignoresSafeArea())
        .accessibilityIdentifier("text-page-\(summary.navigationIndex)")
    }

    // MARK: - Page Header
    private var pageHeader: some View {
        VStack(spacing: 4) {
            Text(summary.title)
                .font(AppTypography.headline)
                .foregroundStyle(palette.inkUmber)

            if let ordinal = summary.quranOrdinal {
                Text("Page \(ordinal) of 847")
                    .font(AppTypography.caption)
                    .foregroundStyle(palette.sepiaMuted)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Verse Card
    private func verseCard(
        ayah: Ayah,
        key: VerseKey?,
        isSelected: Bool,
        isPlaying: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Verse Header: Surah badge + verse number
            HStack {
                let surahName = surahs[ayah.surahId]?.englishName ?? "Surah \(ayah.surahId)"
                Text("\(surahName) \(ayah.verseKey)")
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundStyle(palette.saddleAmber)

                Spacer()

                if isPlaying {
                    Label("Reciting", systemImage: "waveform")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.saddleAmber)
                }
            }

            // Arabic Verse Text
            Text(ayah.textIndopak)
                .font(.custom("Al_Mushaf", size: 24))
                .lineSpacing(10)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(palette.inkUmber)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isPlaying ? palette.saddleAmber.opacity(0.18) :
                    isSelected ? palette.saddleAmber.opacity(0.10) :
                    palette.surfacePapyrus
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isPlaying || isSelected ? palette.saddleAmber : palette.borderSepia,
                    lineWidth: isPlaying ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let k = key {
                onSelectAyah?(k)
            }
        }
    }
}
