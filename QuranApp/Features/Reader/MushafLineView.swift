//
//  MushafLineView.swift
//  QuranApp
//
//  Decoration for a Surah-name slot only. Ayah text and Bismillah are shaped by
//  MushafTextCanvas, so drawing and touch coordinates cannot drift apart.
//

import SwiftUI

struct MushafLineView: View {
    let line: MushafLine
    let surah: Surah?
    let palette: ThemePalette

    var body: some View {
        SurahCartoucheView(
            surahNumber: line.surahId ?? 1,
            arabicName: surah?.arabicName ?? "",
            revelationType: surah?.revelationType.rawValue,
            totalVerses: surah?.totalVerses ?? 0,
            totalRukus: SurahCartoucheView.defaultRukus(for: line.surahId ?? 1),
            palette: palette
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Surah \(surah?.englishName ?? String(line.surahId ?? 1))")
    }
}
