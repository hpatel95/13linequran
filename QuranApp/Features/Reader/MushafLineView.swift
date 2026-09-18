//
//  MushafLineView.swift
//  QuranApp
//
//  Renders an individual line within the 13-line physical Mushaf layout.
//  Supports word-accurate Ayah selection and fluid highlight overlays.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct MushafLineView: View {
    public let line: MushafLine
    public let selectedVerseKey: String?
    public let surahNameArabic: String?
    public let surahNameEnglish: String?
    public let onSelectAyah: ((Int, Int) -> Void)?

    public init(
        line: MushafLine,
        selectedVerseKey: String? = nil,
        surahNameArabic: String? = nil,
        surahNameEnglish: String? = nil,
        onSelectAyah: ((Int, Int) -> Void)? = nil
    ) {
        self.line = line
        self.selectedVerseKey = selectedVerseKey
        self.surahNameArabic = surahNameArabic
        self.surahNameEnglish = surahNameEnglish
        self.onSelectAyah = onSelectAyah
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
                    .accessibilityLabel("Bismillah ir-Rahman ir-Rahim")

            case .ayahText:
                if line.words.isEmpty {
                    fallbackTextLine
                } else {
                    clusteredWordsLine
                }
            }
        }
        .frame(height: 38)
    }

    // MARK: - Clustered Words Line with Ayah Selection Highlighting
    private var clusteredWordsLine: some View {
        HStack(spacing: 4) {
            ForEach(groupedAyahClusters) { cluster in
                let isSelected = selectedVerseKey == cluster.key
                HStack(spacing: 3) {
                    ForEach(cluster.words) { word in
                        Text(word.text)
                            .font(AppTypography.arabic13Line)
                            .foregroundStyle(AppColors.inkUmber)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(isSelected ? AppColors.ayahHighlightGlaze : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isSelected ? AppColors.ayahHighlightBorder : Color.clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    triggerSelectionHaptic()
                    onSelectAyah?(cluster.surah, cluster.ayah)
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isSelected)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Surah \(cluster.surah), Verse \(cluster.ayah)")
                .accessibilityHint("Double tap to select verse and open translation")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: line.isCentered ? .center : .trailing)
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Fallback Text Line
    private var fallbackTextLine: some View {
        Text(line.textIndopak)
            .font(AppTypography.arabic13Line)
            .foregroundStyle(AppColors.inkUmber)
            .multilineTextAlignment(line.isCentered ? .center : .trailing)
            .frame(maxWidth: .infinity, alignment: line.isCentered ? .center : .trailing)
            .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Cluster Grouping Helper
    private struct AyahCluster: Identifiable {
        let key: String // "surah:ayah"
        let surah: Int
        let ayah: Int
        let words: [MushafWord]
        var id: String { key }
    }

    private var groupedAyahClusters: [AyahCluster] {
        var clusters: [AyahCluster] = []
        var currentKey: String?
        var currentSurah = 0
        var currentAyah = 0
        var currentWords: [MushafWord] = []

        for word in line.words {
            let key = "\(word.surah):\(word.ayah)"
            if key == currentKey {
                currentWords.append(word)
            } else {
                if let key = currentKey, !currentWords.isEmpty {
                    clusters.append(AyahCluster(key: key, surah: currentSurah, ayah: currentAyah, words: currentWords))
                }
                currentKey = key
                currentSurah = word.surah
                currentAyah = word.ayah
                currentWords = [word]
            }
        }
        if let key = currentKey, !currentWords.isEmpty {
            clusters.append(AyahCluster(key: key, surah: currentSurah, ayah: currentAyah, words: currentWords))
        }
        return clusters
    }

    private func triggerSelectionHaptic() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}
