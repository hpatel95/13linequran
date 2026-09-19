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
    public let revelationType: String?
    public let totalVerses: Int?
    public let onSelectAyah: ((Int, Int) -> Void)?

    public init(
        line: MushafLine,
        selectedVerseKey: String? = nil,
        surahNameArabic: String? = nil,
        surahNameEnglish: String? = nil,
        revelationType: String? = nil,
        totalVerses: Int? = nil,
        onSelectAyah: ((Int, Int) -> Void)? = nil
    ) {
        self.line = line
        self.selectedVerseKey = selectedVerseKey
        self.surahNameArabic = surahNameArabic
        self.surahNameEnglish = surahNameEnglish
        self.revelationType = revelationType
        self.totalVerses = totalVerses
        self.onSelectAyah = onSelectAyah
    }

    public var body: some View {
        Group {
            switch line.lineType {
            case .surahName:
                IslamicBanner(
                    surahNumber: line.surahId ?? 1,
                    arabicName: surahNameArabic ?? "",
                    revelationType: revelationType,
                    totalVerses: totalVerses ?? 0
                )
                .padding(.horizontal, 2)

            case .bismillah:
                Text("﷽")
                    .font(AppTypography.arabicCalligraphy(size: 24, weight: .regular))
                    .foregroundStyle(AppColors.saddleAmber)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel("Bismillah ir-Rahman ir-Rahim")

            case .ayahText:
                calligraphicLine
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .frame(minHeight: 36)
    }

    // MARK: - Justified Full Calligraphic Line
    private var calligraphicLine: some View {
        Text(line.textIndopak)
            .font(AppTypography.arabic13Line(size: 22))
            .foregroundStyle(AppColors.inkUmber)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .multilineTextAlignment(line.isCentered ? .center : .trailing)
            .frame(maxWidth: .infinity, alignment: line.isCentered ? .center : .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isLineSelected ? AppColors.ayahHighlightGlaze : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(isLineSelected ? AppColors.ayahHighlightBorder : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                triggerSelectionHaptic()
                if let firstWord = line.words.first {
                    onSelectAyah?(firstWord.surah, firstWord.ayah)
                } else if let surahId = line.surahId {
                    onSelectAyah?(surahId, 1)
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isLineSelected)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabelText)
            .accessibilityHint("Long press to view verse options and translation")
    }

    private var isLineSelected: Bool {
        guard let selectedVerseKey = selectedVerseKey else { return false }
        return line.words.contains(where: { "\($0.surah):\($0.ayah)" == selectedVerseKey })
    }

    private var accessibilityLabelText: String {
        if let first = line.words.first {
            return "Surah \(first.surah), Verse \(first.ayah) line"
        }
        return "Line \(line.lineNumber)"
    }

    private func triggerSelectionHaptic() {
        #if canImport(UIKit)
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        #endif
    }
}
