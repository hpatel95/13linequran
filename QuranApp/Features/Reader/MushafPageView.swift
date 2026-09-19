//
//  MushafPageView.swift
//  QuranApp
//
//  Renders a full 13-line Mushaf page inside the ornamental lithograph frame.
//

import SwiftUI

public struct MushafPageView: View {
    public let pageNumber: Int
    public let lines: [MushafLine]
    public let surahName: String
    public let surahArabicName: String
    public let juzNumber: Int
    public let juzArabicName: String
    public let revelationType: String?
    public let totalVerses: Int?
    public let selectedVerseKey: String?
    public let onSelectAyah: ((Int, Int) -> Void)?

    public init(
        pageNumber: Int,
        lines: [MushafLine],
        surahName: String = "",
        surahArabicName: String = "",
        juzNumber: Int = 1,
        juzArabicName: String = "",
        revelationType: String? = nil,
        totalVerses: Int? = nil,
        selectedVerseKey: String? = nil,
        onSelectAyah: ((Int, Int) -> Void)? = nil
    ) {
        self.pageNumber = pageNumber
        self.lines = lines
        self.surahName = surahName
        self.surahArabicName = surahArabicName
        self.juzNumber = juzNumber
        self.juzArabicName = juzArabicName
        self.revelationType = revelationType
        self.totalVerses = totalVerses
        self.selectedVerseKey = selectedVerseKey
        self.onSelectAyah = onSelectAyah
    }

    public var body: some View {
        QuranPageFrame(
            pageNumber: pageNumber,
            surahName: surahName,
            surahArabicName: surahArabicName,
            juzNumber: juzNumber,
            juzArabicName: juzArabicName
        ) {
            if lines.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.saddleAmber)
                    Spacer()
                }
                .frame(minHeight: 500)
            } else {
                ForEach(lines) { line in
                    MushafLineView(
                        line: line,
                        selectedVerseKey: selectedVerseKey,
                        surahNameArabic: surahArabicName,
                        surahNameEnglish: surahName,
                        revelationType: revelationType,
                        totalVerses: totalVerses,
                        onSelectAyah: onSelectAyah
                    )
                }
            }
        }
    }
}
