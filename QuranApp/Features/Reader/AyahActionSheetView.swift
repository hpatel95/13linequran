//
//  AyahActionSheetView.swift
//  QuranApp
//
//  Interactive bottom sheet presented when an Ayah is selected.
//  Implements Apple HIG 44pt touch targets, SF Symbols, fluid springs,
//  and comprehensive actions: Play, Bookmark, Copy, Share, and Repeat Loop.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct AyahActionSheetView: View {
    public let ayah: Ayah
    public let surah: Surah?
    public let translation: Translation?
    public let onPlay: () -> Void
    public let onBookmark: () -> Void
    public let onSelectAuthor: (Translation.TranslationAuthor) -> Void
    public let isBookmarked: Bool

    @State private var copyFeedbackTriggered: Bool = false
    @State private var repeatCount: Int = 1
    @Environment(\.dismiss) private var dismiss

    public init(
        ayah: Ayah,
        surah: Surah?,
        translation: Translation?,
        isBookmarked: Bool = false,
        onPlay: @escaping () -> Void,
        onBookmark: @escaping () -> Void,
        onSelectAuthor: @escaping (Translation.TranslationAuthor) -> Void
    ) {
        self.ayah = ayah
        self.surah = surah
        self.translation = translation
        self.isBookmarked = isBookmarked
        self.onPlay = onPlay
        self.onBookmark = onBookmark
        self.onSelectAuthor = onSelectAuthor
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header Bar with Surah & Ayah Badges
                    headerSection

                    Divider()
                        .overlay(AppColors.borderSepia)

                    // Arabic Calligraphic Verse
                    arabicVerseSection

                    // English / French Translation Section
                    translationSection

                    Divider()
                        .overlay(AppColors.borderSepia)

                    // Action Buttons (Bookmark, Copy, Share)
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .background(AppColors.paperAged.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("ayah-sheet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppColors.sepiaMuted)
                            .frame(minWidth: 44, minHeight: 44) // 44pt HIG
                    }
                    .accessibilityLabel("Close Ayah sheet")
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(surah?.englishName ?? "Surah \(ayah.surahId)")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.inkUmber)

                    // Surah Number Badge
                    Text(String(format: "%03d", ayah.surahId))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.saddleAmber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.surfacePapyrus)
                        .clipShape(Capsule())
                }

                Text("Page \(ayah.pageNumber) • Juz \(ayah.juzNumber)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)

                // Machine-readable verse key, asserted by automated UI tests to
                // prove which Ayah the long press actually resolved.
                Text("Verse key \(ayah.verseKey)")
                    .font(.system(size: 1))
                    .foregroundStyle(AppColors.sepiaMuted.opacity(0.001))
                    .accessibilityIdentifier("ayah-sheet-key")
                    .frame(height: 1)
                    .accessibilityLabel("Selected verse \(ayah.verseKey)")
            }

            Spacer()

            // Ayah Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(surah?.arabicName ?? "")
                    .font(AppTypography.surahHeader)
                    .foregroundStyle(AppColors.inkUmber)

                Text("Ayah \(ayah.verseNumber)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.saddleAmber)
            }
        }
    }

    // MARK: - Arabic Verse Display
    private var arabicVerseSection: some View {
        Text(ayah.textIndopak)
            .font(AppTypography.arabic13Line)
            .foregroundStyle(AppColors.inkUmber)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .padding(.vertical, 4)
    }

    // MARK: - Translation Display
    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let authorName = translation?.authorCode.displayName {
                    HStack(spacing: 5) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 11))
                        Text(authorName)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.saddleAmber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.surfacePapyrus)
                    .clipShape(Capsule())
                }

                Spacer()

                if copyFeedbackTriggered {
                    Text("Copied!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.saddleAmber)
                        .transition(.opacity.combined(with: .scale))
                }
            }

            // Translation Text
            if let text = translation?.text, !text.isEmpty {
                Text(text)
                    .font(AppTypography.englishTranslation)
                    .foregroundStyle(AppColors.inkUmber)
                    .lineSpacing(5)
            } else {
                Text("Loading translation...")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Action Buttons (Play, Bookmark, Copy, Share)
    private var actionButtonsSection: some View {
        HStack(spacing: 10) {
            // 1. Play Button
            actionButton(
                title: "Play",
                systemImage: "play.fill",
                action: {
                    triggerHaptic()
                    onPlay()
                    dismiss()
                }
            )

            // 2. Bookmark Button
            actionButton(
                title: isBookmarked ? "Saved" : "Bookmark",
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark",
                isActive: isBookmarked,
                action: {
                    triggerHaptic()
                    onBookmark()
                }
            )

            // 2. Copy Button
            actionButton(
                title: "Copy",
                systemImage: "doc.on.doc",
                action: {
                    copyToClipboard()
                }
            )

            // 3. Share Link
            ShareLink(
                item: "\(ayah.textIndopak)\n\n\(translation?.text ?? "")\n— [Surah \(surah?.englishName ?? "") \(ayah.verseKey)]"
            ) {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                    Text("Share")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppColors.surfacePapyrus)
                .foregroundStyle(AppColors.inkUmber)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(SpringTouchDownStyle())
        }
    }

    // MARK: - Action Button Builder
    private func actionButton(
        title: String,
        systemImage: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 48) // 48pt ensures >44pt HIG
            .background(isActive ? AppColors.saddleAmber.opacity(0.15) : AppColors.surfacePapyrus)
            .foregroundStyle(isActive ? AppColors.saddleAmber : AppColors.inkUmber)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? AppColors.saddleAmber : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(SpringTouchDownStyle())
    }

    private func copyToClipboard() {
        triggerHaptic()
        let textToCopy = """
        \(ayah.textIndopak)

        \(translation?.text ?? "")
        — [Surah \(surah?.englishName ?? "\(ayah.surahId)") \(ayah.verseKey)] (\(translation?.authorCode.displayName ?? ""))
        """

        #if canImport(UIKit)
        UIPasteboard.general.string = textToCopy
        #endif

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            copyFeedbackTriggered = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { copyFeedbackTriggered = false }
        }
    }

    private func triggerHaptic() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Spring Touch Down Feedback Style (Apple Fluid Motion)
public struct SpringTouchDownStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 1.0), value: configuration.isPressed)
    }
}
