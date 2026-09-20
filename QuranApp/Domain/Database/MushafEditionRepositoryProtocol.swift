//
//  MushafEditionRepositoryProtocol.swift
//  QuranApp
//
//  Abstract interface for querying authentic Mushaf edition manifests,
//  page layouts, interactive bounding regions, and navigation anchors.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

public protocol MushafEditionRepositoryProtocol: Sendable {
    /// Returns all registered Mushaf editions in the catalog.
    func fetchEditions() async throws -> [MushafEdition]

    /// Returns the specific edition metadata for the given edition identifier.
    func fetchEdition(editionId: String) async throws -> MushafEdition?

    /// Returns lightweight summary metadata for all pages of an edition, ordered by navigation index.
    func fetchPages(editionId: String) async throws -> [MushafPageSummary]

    /// Fetches complete page content including verse memberships and hit-testable bounding regions.
    func fetchPage(editionId: String, pageId: String) async throws -> MushafPageContent?

    /// Fetches page content by 1-based navigation index (1...totalPages).
    func fetchPageByNavigationIndex(editionId: String, index: Int) async throws -> MushafPageContent?

    /// Fetches page content by 1-based Quran page ordinal (1...847).
    func fetchPageByQuranOrdinal(editionId: String, ordinal: Int) async throws -> MushafPageContent?

    /// Finds all reader locations across pages where the given canonical verse appears.
    func fetchLocations(editionId: String, verse: VerseKey) async throws -> [ReaderLocation]

    /// Finds the reader location corresponding to a navigation anchor (e.g. Surah start or Juz start).
    func fetchAnchor(editionId: String, kind: NavigationAnchorKind, number: Int) async throws -> ReaderLocation?

    /// Resolves a 1-based Quran ordinal to a reader location.
    func fetchPageForQuranOrdinal(editionId: String, ordinal: Int) async throws -> ReaderLocation?

    /// Returns the active default edition identifier.
    var defaultEditionId: String { get }
}
