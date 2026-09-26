//
//  MarginRubricView.swift
//  QuranApp
//
//  Classical physical Mushaf margin rubrics for:
//    - Hizb quarters: رُبْع (1/4), نِصْف (1/2), ثَلَاثَة (3/4)
//    - Sajdah Tilawah prostration badges: سَجْدَة with numeral
//    - Quran midpoint marker: نِصْفُ القُرْآن
//    - Mu'anaqah embracing pause notation: مُعَانَقَة
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI

public struct MarginRubricView: View {
    public let rubric: MarginRubric
    public let palette: ThemePalette

    public init(rubric: MarginRubric, palette: ThemePalette = AppColors.palette(for: .sepia)) {
        self.rubric = rubric
        self.palette = palette
    }

    public var body: some View {
        Group {
            switch rubric.kind {
            case .quarter(let quarterType):
                quarterBadge(quarterType)
            case .sajdah(let number):
                sajdahBadge(number)
            case .middleOfQuran:
                middleOfQuranBadge
            case .muanaqah:
                muanaqahBadge
            case .juzStart(let num, let name):
                juzBadge(num, name: name)
            case .manzil(let num):
                manzilBadge(num)
            }
        }
        .frame(width: 23)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Hizb Quarter Badge (رُبْع, نِصْف, ثَلَاثَة)
    private func quarterBadge(_ type: MarginRubric.QuarterType) -> some View {
        VStack(spacing: 1.0) {
            Text(type.rawValue)
                .font(AppTypography.arabicCalligraphy(size: 11, weight: .bold))
                .foregroundStyle(palette.saddleAmber)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(.horizontal, 1.5)
        .padding(.vertical, 3.0)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(palette.surfacePapyrus.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .strokeBorder(palette.saddleAmber.opacity(0.5), lineWidth: 0.75)
        )
    }

    // MARK: - Sajdah Tilawah Prostration Badge (سَجْدَة)
    private func sajdahBadge(_ number: Int) -> some View {
        VStack(spacing: 1.0) {
            Text("سَجْدَة")
                .font(AppTypography.arabicCalligraphy(size: 10, weight: .bold))
                .foregroundStyle(palette.saddleAmber)
                .lineLimit(1)

            Text(AppTypography.easternArabicDigits(number))
                .font(.system(size: 8.5, weight: .bold, design: .serif))
                .foregroundStyle(palette.inkUmber)
                .lineLimit(1)
        }
        .padding(.horizontal, 1.5)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(palette.surfacePapyrus.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .strokeBorder(palette.saddleAmber, lineWidth: 0.85)
        )
    }

    // MARK: - Middle of Quran (وَلْيَتَلَطَّفْ / نِصْفُ القُرْآن)
    private var middleOfQuranBadge: some View {
        VStack(spacing: 0.5) {
            Text("نِصْفُ")
                .font(AppTypography.arabicCalligraphy(size: 9.5, weight: .bold))
                .foregroundStyle(palette.saddleAmber)
            Text("القُرْآن")
                .font(AppTypography.arabicCalligraphy(size: 9.5, weight: .bold))
                .foregroundStyle(palette.saddleAmber)
        }
        .padding(.horizontal, 1.0)
        .padding(.vertical, 2.5)
        .background(
            RoundedRectangle(cornerRadius: 3.5)
                .fill(palette.surfacePapyrus.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.5)
                .strokeBorder(palette.saddleAmber.opacity(0.6), lineWidth: 0.75)
        )
    }

    // MARK: - Mu'anaqah Embracing Pause Notation (مُعَانَقَة)
    private var muanaqahBadge: some View {
        VStack(spacing: 0.5) {
            Text("∴")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.saddleAmber)
            Text("مُعَانَقَة")
                .font(AppTypography.arabicCalligraphy(size: 8.5, weight: .bold))
                .foregroundStyle(palette.sepiaMuted)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.horizontal, 1.0)
        .padding(.vertical, 2.0)
        .background(
            RoundedRectangle(cornerRadius: 3.0)
                .fill(palette.surfacePapyrus.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.0)
                .strokeBorder(palette.borderSepia.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Juz Start Badge
    private func juzBadge(_ num: Int, name: String) -> some View {
        VStack(spacing: 0.5) {
            Text("الجُزْء")
                .font(AppTypography.arabicCalligraphy(size: 9, weight: .bold))
                .foregroundStyle(palette.saddleAmber)
            Text(AppTypography.easternArabicDigits(num))
                .font(.system(size: 8, weight: .bold, design: .serif))
                .foregroundStyle(palette.inkUmber)
        }
        .padding(.horizontal, 1.0)
        .padding(.vertical, 2.0)
        .background(
            RoundedRectangle(cornerRadius: 3.0)
                .fill(palette.surfacePapyrus.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.0)
                .strokeBorder(palette.saddleAmber.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Manzil Badge
    private func manzilBadge(_ num: Int) -> some View {
        VStack(spacing: 0.5) {
            Text("مَنْزِل")
                .font(AppTypography.arabicCalligraphy(size: 9, weight: .bold))
                .foregroundStyle(palette.sepiaMuted)
            Text(AppTypography.easternArabicDigits(num))
                .font(.system(size: 8, weight: .bold, design: .serif))
                .foregroundStyle(palette.sepiaMuted)
        }
        .padding(.horizontal, 1.0)
        .padding(.vertical, 2.0)
        .background(
            RoundedRectangle(cornerRadius: 3.0)
                .fill(palette.surfacePapyrus.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 3.0)
                .strokeBorder(palette.borderSepia.opacity(0.35), lineWidth: 0.5)
        )
    }

    private var accessibilityText: String {
        switch rubric.kind {
        case .quarter(let q): return "Hizb Quarter \(q.rawValue)"
        case .sajdah(let num): return "Sajdah \(num)"
        case .middleOfQuran: return "Middle of the Quran"
        case .muanaqah: return "Mu'anaqah pause marker"
        case .juzStart(let num, let name): return "Juz \(num) \(name)"
        case .manzil(let num): return "Manzil \(num)"
        }
    }
}
