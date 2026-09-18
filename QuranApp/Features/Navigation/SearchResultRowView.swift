//
//  SearchResultRowView.swift
//  QuranApp
//
//  Card view for FTS5 full-text search results with golden keyword highlighting,
//  RTL Arabic scripture preview, and direct page navigation metadata.
//

import SwiftUI

public struct SearchResultRowView: View {
    public let result: SearchResult
    public let searchQuery: String
    public let onSelect: () -> Void

    public init(
        result: SearchResult,
        searchQuery: String,
        onSelect: @escaping () -> Void
    ) {
        self.result = result
        self.searchQuery = searchQuery
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onSelect()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Header badge: Surah : Ayah • Page
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.saddleAmber)
                        Text("Surah \(result.surahId):\(result.verseNumber)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.saddleAmber)
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.borderSepia)
                        Text("Page \(result.pageNumber)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.primaryDeepAmber)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.surfacePapyrus.opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.borderSepia, lineWidth: 0.5))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.sepiaMuted)
                }

                // Arabic clean text (RTL)
                Text(result.arabicClean)
                    .font(AppTypography.arabic13Line)
                    .foregroundStyle(AppColors.inkUmber)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)

                // Translation with golden highlight
                Text(highlightedTranslation(result.translationEnSaheeh, matching: searchQuery))
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.sepiaMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.paperAged.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.borderSepia, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(IndexRowButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Surah \(result.surahId), Verse \(result.verseNumber), Page \(result.pageNumber). Translation: \(result.translationEnSaheeh)")
        .accessibilityHint("Double tap to open reading page and view verse")
    }

    // MARK: - Keyword Highlighting
    private func highlightedTranslation(_ text: String, matching query: String) -> AttributedString {
        var attributed = AttributedString(text)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return attributed }

        let searchWords = trimmed.split(separator: " ").map(String.init)
        for word in searchWords where word.count >= 2 {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let range = attributed[searchRange].range(of: word, options: .caseInsensitive) {
                attributed[range].foregroundColor = AppColors.saddleAmber
                attributed[range].font = .system(size: 13, weight: .bold, design: .serif)
                attributed[range].backgroundColor = AppColors.ayahHighlightGlaze

                if range.upperBound < attributed.endIndex {
                    searchRange = range.upperBound..<attributed.endIndex
                } else {
                    break
                }
            }
        }
        return attributed
    }
}
