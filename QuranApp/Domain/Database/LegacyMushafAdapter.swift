//
//  LegacyMushafAdapter.swift
//  QuranApp
//
//  Bridges the legacy 849-page Qudratullah Core Text engine to the unified
//  MushafEditionRepositoryProtocol and ReaderLocation navigation models.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

public final class LegacyMushafAdapter: MushafEditionRepositoryProtocol, @unchecked Sendable {
    public let defaultEditionId: String = "legacy-qudratullah-13-849"
    private let quranService: any QuranRepositoryProtocol

    public init(quranService: any QuranRepositoryProtocol) {
        self.quranService = quranService
    }

    public func fetchEditions() async throws -> [MushafEdition] {
        [
            MushafEdition(
                id: defaultEditionId,
                contentVersion: 1,
                displayName: "IndoPak 13-Line (Accessible Text)",
                publisher: "Qudratullah",
                rendererKind: .legacyText,
                approvalStatus: .approved,
                quranPageCount: 849,
                navigationPageCount: 849,
                noticePath: nil
            )
        ]
    }

    public func fetchEdition(editionId: String) async throws -> MushafEdition? {
        guard editionId == defaultEditionId else { return nil }
        return try await fetchEditions().first
    }

    public func fetchPages(editionId: String) async throws -> [MushafPageSummary] {
        guard editionId == defaultEditionId else { return [] }
        return (1...849).map { page in
            MushafPageSummary(
                id: String(format: "p%04d", page),
                editionId: defaultEditionId,
                navigationIndex: page,
                quranOrdinal: page,
                printedLabel: "\(page)",
                kind: .quran,
                title: "Page \(page)",
                sourceAssetId: "\(page)",
                sourceWidth: nil,
                sourceHeight: nil,
                imagePath: nil,
                imageSha256: nil
            )
        }
    }

    public func fetchPage(editionId: String, pageId: String) async throws -> MushafPageContent? {
        guard editionId == defaultEditionId else { return nil }
        guard let numStr = pageId.components(separatedBy: CharacterSet.decimalDigits.inverted).last,
              let page = Int(numStr), (1...849).contains(page) else {
            return nil
        }
        return try await fetchPageByNavigationIndex(editionId: editionId, index: page)
    }

    public func fetchPageByNavigationIndex(editionId: String, index: Int) async throws -> MushafPageContent? {
        guard editionId == defaultEditionId, (1...849).contains(index) else { return nil }
        let ayahs = try await quranService.fetchAyahs(forPage: index)
        let summary = MushafPageSummary(
            id: String(format: "p%04d", index),
            editionId: defaultEditionId,
            navigationIndex: index,
            quranOrdinal: index,
            printedLabel: "\(index)",
            kind: .quran,
            title: "Page \(index)",
            sourceAssetId: "\(index)",
            sourceWidth: nil,
            sourceHeight: nil,
            imagePath: nil,
            imageSha256: nil
        )

        let verses: [PageVerseMembership] = ayahs.enumerated().compactMap { (order, ayah) -> PageVerseMembership? in
            guard let key = VerseKey(surah: ayah.surahId, ayah: ayah.verseNumber) else { return nil }
            return PageVerseMembership(
                verseKey: key,
                readingOrder: order + 1,
                startsHere: true,
                endsHere: true
            )
        }

        return MushafPageContent(summary: summary, verses: verses, regions: [])
    }

    public func fetchPageByQuranOrdinal(editionId: String, ordinal: Int) async throws -> MushafPageContent? {
        return try await fetchPageByNavigationIndex(editionId: editionId, index: ordinal)
    }

    public func fetchLocations(editionId: String, verse: VerseKey) async throws -> [ReaderLocation] {
        guard editionId == defaultEditionId else { return [] }
        guard let ayah = try await quranService.fetchAyah(surah: verse.surah, verse: verse.ayah) else {
            return []
        }
        let loc = ReaderLocation(
            editionId: defaultEditionId,
            pageId: String(format: "p%04d", ayah.pageNumber),
            navigationIndex: ayah.pageNumber,
            quranOrdinal: ayah.pageNumber,
            surahId: ayah.surahId,
            juzNumber: ayah.juzNumber,
            focusedVerse: verse,
            label: "\(ayah.pageNumber)"
        )
        return [loc]
    }

    public func fetchAnchor(editionId: String, kind: NavigationAnchorKind, number: Int) async throws -> ReaderLocation? {
        guard editionId == defaultEditionId else { return nil }
        switch kind {
        case .surah:
            guard let surah = try await quranService.fetchSurah(id: number) else { return nil }
            return ReaderLocation(
                editionId: defaultEditionId,
                pageId: String(format: "p%04d", surah.startPage),
                navigationIndex: surah.startPage,
                quranOrdinal: surah.startPage,
                surahId: surah.id,
                juzNumber: surah.juzNumber,
                focusedVerse: VerseKey(surah: surah.id, ayah: 1),
                label: "\(surah.startPage)"
            )
        case .juz:
            guard (1...30).contains(number) else { return nil }
            if let juz = try await quranService.fetchJuz(number: number) {
                return ReaderLocation(
                    editionId: defaultEditionId,
                    pageId: String(format: "p%04d", juz.startPage),
                    navigationIndex: juz.startPage,
                    quranOrdinal: juz.startPage,
                    surahId: juz.startSurahId,
                    juzNumber: number,
                    focusedVerse: VerseKey(surah: juz.startSurahId, ayah: juz.startVerseNumber),
                    label: "\(juz.startPage)"
                )
            }
            return nil
        case .rubElHizb, .manzil:
            return nil
        }
    }

    public func fetchPageForQuranOrdinal(editionId: String, ordinal: Int) async throws -> ReaderLocation? {
        guard editionId == defaultEditionId, (1...849).contains(ordinal) else { return nil }
        let ayahs = try await quranService.fetchAyahs(forPage: ordinal)
        return ReaderLocation(
            editionId: defaultEditionId,
            pageId: String(format: "p%04d", ordinal),
            navigationIndex: ordinal,
            quranOrdinal: ordinal,
            surahId: ayahs.first?.surahId,
            juzNumber: ayahs.first?.juzNumber,
            focusedVerse: nil,
            label: "\(ordinal)"
        )
    }
}
