//
//  JuzRowView.swift
//  QuranApp
//
//  Pixel-accurate Juz (Part) list item displaying canonical Arabic opening title,
//  English transliteration, starting verse location, verse count, and start page.
//

import SwiftUI

public struct JuzRowView: View {
    public let juz: Juz
    public let startingSurahName: String
    public let onSelect: () -> Void

    public init(
        juz: Juz,
        startingSurahName: String,
        onSelect: @escaping () -> Void
    ) {
        self.juz = juz
        self.startingSurahName = startingSurahName
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onSelect()
        }) {
            HStack(spacing: 12) {
                // Left: Circular Badge (36x36)
                ZStack {
                    Circle()
                        .fill(AppColors.surfacePapyrus.opacity(0.70))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppColors.borderSepia, lineWidth: 1))

                    Text("\(juz.id)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(AppColors.saddleAmber)
                }

                // Middle: English title & verse starting info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Juz \(juz.id)")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(AppColors.inkUmber)

                        Text("• \(juz.nameTransliteration)")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(AppColors.sepiaMuted)
                            .lineLimit(1)
                    }

                    HStack(spacing: 5) {
                        Text("\(startingSurahName) \(juz.startSurahId):\(juz.startVerseNumber)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.saddleAmber)

                        Text("•")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.borderSepia)

                        Text("\(juz.totalVerses) Verses")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.sepiaMuted)
                    }
                }

                Spacer(minLength: 8)

                // Right: Arabic Juz title & Start Page
                VStack(alignment: .trailing, spacing: 4) {
                    Text(juz.nameArabic)
                        .font(AppTypography.surahHeader)
                        .foregroundStyle(AppColors.inkUmber)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text("p. \(juz.startPage)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.primaryDeepAmber)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.sepiaMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.paperAged.opacity(0.85))
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
        .accessibilityLabel("Juz \(juz.id), \(juz.nameTransliteration), starts at \(startingSurahName) verse \(juz.startVerseNumber), \(juz.totalVerses) verses, Page \(juz.startPage)")
        .accessibilityHint("Double tap to open reading page")
    }
}
