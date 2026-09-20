//
//  ReaderLocationResolver.swift
//  QuranApp
//
//  Resolves high-level reader destinations (Surah, Juz, Quran page, verse)
//  into concrete, strongly-typed ReaderLocation instances for the active edition.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

public struct ReaderLocationResolver: Sendable {
    private let repository: any MushafEditionRepositoryProtocol

    public init(repository: any MushafEditionRepositoryProtocol) {
        self.repository = repository
    }

    /// Resolves a generic destination to a concrete reader location.
    public func resolve(
        destination: ReaderDestination,
        editionId: String
    ) async throws -> ReaderLocation {
        switch destination {
        case .exact(let location):
            return location

        case .page(let navIndex):
            guard let page = try await repository.fetchPageByNavigationIndex(editionId: editionId, index: navIndex) else {
                throw MushafEditionDatabaseService.DatabaseError.notFound("Page with navigation index \(navIndex)")
            }
            let firstVerse = page.verses.first?.verseKey
            return ReaderLocation(
                editionId: editionId,
                pageId: page.summary.id,
                navigationIndex: page.summary.navigationIndex,
                quranOrdinal: page.summary.quranOrdinal,
                surahId: firstVerse?.surah,
                juzNumber: nil,
                focusedVerse: nil,
                label: page.summary.printedLabel
            )

        case .quranOrdinal(let ordinal):
            if let loc = try await repository.fetchPageForQuranOrdinal(editionId: editionId, ordinal: ordinal) {
                return loc
            }
            // Fallback to index if within range
            return try await resolve(destination: .page(navigationIndex: ordinal), editionId: editionId)

        case .surah(let surahId, let ayahNumber):
            if let ayah = ayahNumber, ayah > 1, let key = VerseKey(surah: surahId, ayah: ayah) {
                let locations = try await repository.fetchLocations(editionId: editionId, verse: key)
                if let first = locations.first {
                    return first
                }
            }
            // Start of surah anchor
            if let anchor = try await repository.fetchAnchor(editionId: editionId, kind: .surah, number: surahId) {
                return anchor
            }
            // If anchor lookup fails, fallback to page 1
            return try await resolve(destination: .page(navigationIndex: 1), editionId: editionId)

        case .juz(let juzNumber):
            if let anchor = try await repository.fetchAnchor(editionId: editionId, kind: .juz, number: juzNumber) {
                return anchor
            }
            return try await resolve(destination: .page(navigationIndex: 1), editionId: editionId)

        case .verse(let verseKey):
            let locations = try await repository.fetchLocations(editionId: editionId, verse: verseKey)
            if let first = locations.first {
                return first
            }
            // If verse not found, fallback to surah anchor
            return try await resolve(destination: .surah(surahId: verseKey.surah, ayahNumber: verseKey.ayah), editionId: editionId)
        }
    }
}
