//
//  SurahRowView.swift
//  QuranApp
//
//  Pixel-accurate Surah list item matching the Stitch "Surahs & Juz Navigation Index" design.
//  Includes distinct Meccan/Medinan pill styling, Juz span notation, 44pt touch targets,
//  and special "Currently Reading" card state.
//

import SwiftUI

public struct SurahRowView: View {
    public let surah: Surah
    public let juzSpan: String
    public let isCurrentlyReading: Bool
    public let onSelect: () -> Void

    public init(
        surah: Surah,
        juzSpan: String,
        isCurrentlyReading: Bool = false,
        onSelect: @escaping () -> Void
    ) {
        self.surah = surah
        self.juzSpan = juzSpan
        self.isCurrentlyReading = isCurrentlyReading
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onSelect()
        }) {
            ZStack(alignment: .topLeading) {
                // Card chassis
                HStack(spacing: 12) {
                    // Left: Circular Number Badge (36x36)
                    numberBadge

                    // Middle: English title, meaning, badges, and juz span
                    titleBlock

                    Spacer(minLength: 8)

                    // Right: Arabic calligraphy & Page indicator
                    trailingBlock
                }
                .padding(.horizontal, 14)
                .padding(.vertical, isCurrentlyReading ? 14 : 12)
                .frame(minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.paperAged.opacity(isCurrentlyReading ? 1.0 : 0.85))
                        .shadow(color: Color.black.opacity(isCurrentlyReading ? 0.08 : 0.03), radius: isCurrentlyReading ? 6 : 2, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isCurrentlyReading ? AppColors.saddleAmber.opacity(0.85) : AppColors.borderSepia,
                            lineWidth: isCurrentlyReading ? 1.5 : 1
                        )
                )

                // "Currently Reading" Ribbon Tag
                if isCurrentlyReading {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 8))
                        Text("CURRENTLY READING")
                            .font(.system(size: 8, weight: .bold, design: .default))
                            .tracking(0.6)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.saddleAmber)
                    .clipShape(Capsule())
                    .offset(x: 14, y: -9)
                    .shadow(color: AppColors.saddleAmber.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(IndexRowButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(surah.id), Surah \(surah.englishName), \(surah.englishMeaning), \(surah.revelationType.rawValue), \(surah.totalVerses) verses, \(juzSpan), Page \(surah.startPage)")
        .accessibilityHint("Double tap to open reading page")
    }

    // MARK: - Subviews
    private var numberBadge: some View {
        ZStack {
            Circle()
                .fill(isCurrentlyReading ? AppColors.saddleAmber : AppColors.surfacePapyrus.opacity(0.70))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(isCurrentlyReading ? AppColors.saddleAmber : AppColors.borderSepia, lineWidth: 1)
                )

            Text("\(surah.id)")
                .font(.system(size: 13, weight: isCurrentlyReading ? .bold : .medium, design: .serif))
                .foregroundStyle(isCurrentlyReading ? .white : AppColors.inkUmber)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: English Title & Meaning
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(surah.englishName)
                    .font(.system(size: 15, weight: isCurrentlyReading ? .bold : .semibold, design: .serif))
                    .foregroundStyle(AppColors.inkUmber)

                Text("• \(surah.englishMeaning)")
                    .font(.system(size: 12, design: .serif))
                    .foregroundStyle(AppColors.sepiaMuted)
                    .lineLimit(1)
            }

            // Line 2: Revelation Pill, Verse Count, and Juz Span
            HStack(spacing: 5) {
                // Revelation Pill (Distinct styling for Meccan vs Medinan per Stitch)
                if surah.revelationType == .medinan {
                    Text("MEDINAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.medinanTeal)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.medinanBadgeFill)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppColors.borderSepia.opacity(0.7), lineWidth: 0.5))
                } else {
                    Text("MECCAN")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.sepiaMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.surfacePapyrus.opacity(0.90))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(AppColors.borderSepia.opacity(0.7), lineWidth: 0.5))
                }

                Text("•")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.borderSepia)

                Text("\(surah.totalVerses) Verses")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.sepiaMuted)

                Text("•")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.borderSepia)

                Text(juzSpan)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.saddleAmber)
            }
        }
    }

    private var trailingBlock: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(surah.arabicName)
                .font(AppTypography.surahHeader)
                .foregroundStyle(isCurrentlyReading ? AppColors.primaryDeepAmber : AppColors.inkUmber)
                .lineLimit(1)

            HStack(spacing: 4) {
                if isCurrentlyReading {
                    HStack(spacing: 3) {
                        Text("p. \(surah.startPage)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.saddleAmber)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppColors.saddleAmber)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.surfacePapyrus)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.borderSepia, lineWidth: 0.5))
                } else {
                    Text("p. \(surah.startPage)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.primaryDeepAmber)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.sepiaMuted)
                }
            }
        }
    }
}
