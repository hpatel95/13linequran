//
//  BookmarkRowView.swift
//  QuranApp
//
//  Stitch-accurate Bookmark list card rendering either an Ayah bookmark (with Arabic snippet
//  and translation) or a Page bookmark with relative timestamps and 44pt touch targets.
//

import SwiftUI

public struct BookmarkRowView: View {
    public let bookmark: Bookmark
    public let onSelect: () -> Void

    public init(
        bookmark: Bookmark,
        onSelect: @escaping () -> Void
    ) {
        self.bookmark = bookmark
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
                // Header badge row: Bookmark Icon + Title + Chevron
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: bookmark.isPageBookmark ? "book.fill" : "bookmark.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.saddleAmber)

                        Text(bookmark.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.saddleAmber)

                        Text("•")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.borderSepia)

                        Text("p. \(bookmark.pageNumber)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.primaryDeepAmber)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.surfacePapyrus.opacity(0.8))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.borderSepia, lineWidth: 0.5))

                    Spacer()

                    Text(formattedDate(bookmark.createdAt))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.sepiaMuted)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.sepiaMuted)
                }

                // Arabic snippet (if Ayah bookmark)
                if let arabic = bookmark.arabicSnippet, !arabic.isEmpty {
                    Text(arabic)
                        .font(AppTypography.arabic13Line)
                        .foregroundStyle(AppColors.inkUmber)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                // Translation snippet (if Ayah bookmark)
                if let translation = bookmark.translationSnippet, !translation.isEmpty {
                    Text(translation)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.sepiaMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Personal Note (if present)
                if let note = bookmark.note, !note.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.saddleAmber)
                        Text(note)
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundStyle(AppColors.inkUmber)
                    }
                }
            }
            .padding(14)
            .frame(minHeight: 60)
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
        .accessibilityLabel("\(bookmark.title), Page \(bookmark.pageNumber). Saved \(formattedDate(bookmark.createdAt)). \(bookmark.translationSnippet ?? "")")
        .accessibilityHint("Double tap to jump to this bookmark in the reader")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
