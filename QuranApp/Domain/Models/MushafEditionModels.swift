//
//  MushafEditionModels.swift
//  QuranApp
//
//  Immutable domain entities for authentic Mushaf editions, page geometry,
//  normalized regions, and verse memberships.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation

// MARK: - Canonical Verse Key
public struct VerseKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let surah: Int // 1 ... 114
    public let ayah: Int  // 1 ... N (never 0)

    public init?(surah: Int, ayah: Int) {
        guard (1...114).contains(surah), ayah > 0 else { return nil }
        self.surah = surah
        self.ayah = ayah
    }

    public init(validatedSurah surah: Int, ayah: Int) {
        self.surah = surah
        self.ayah = ayah
    }

    public var description: String {
        "\(surah):\(ayah)"
    }
}

// MARK: - Normalized Rectangle ([0, 1] Coordinate Space)
public struct NormalizedRect: Hashable, Codable, Sendable {
    public let minX: Double
    public let minY: Double
    public let maxX: Double
    public let maxY: Double

    public init?(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        guard minX >= 0, minY >= 0, maxX <= 1.0, maxY <= 1.0,
              minX < maxX, minY < maxY else {
            return nil
        }
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(validatedMinX minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var area: Double { width * height }

    /// Checks if a normalized point (u, v) falls within this half-open rectangle.
    public func contains(u: Double, v: Double) -> Bool {
        return u >= minX && u < maxX && v >= minY && v < maxY
    }
}

// MARK: - Region Kind
public enum MushafRegionKind: String, Codable, Sendable {
    case ayah
    case bismillah
    case decoration
    case supplication
}

// MARK: - Interactive Page Region
public struct MushafRegion: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let pageId: String
    public let kind: MushafRegionKind
    public let verseKey: VerseKey?
    public let fragmentOrder: Int
    public let sourceOrder: Int
    public let label: String?
    public let rect: NormalizedRect

    public init(
        id: String,
        pageId: String,
        kind: MushafRegionKind,
        verseKey: VerseKey?,
        fragmentOrder: Int,
        sourceOrder: Int,
        label: String?,
        rect: NormalizedRect
    ) {
        self.id = id
        self.pageId = pageId
        self.kind = kind
        self.verseKey = verseKey
        self.fragmentOrder = fragmentOrder
        self.sourceOrder = sourceOrder
        self.label = label
        self.rect = rect
    }
}

// MARK: - Page Kind
public enum MushafPageKind: String, Codable, Sendable {
    case quran
    case quranAndSupplement
    case supplement
    case frontMatter
}

// MARK: - Page Summary
public struct MushafPageSummary: Identifiable, Hashable, Sendable {
    public let id: String                 // e.g. "p0001"
    public let editionId: String          // e.g. "taj-company-13-847"
    public let navigationIndex: Int       // 1 ... 848
    public let quranOrdinal: Int?         // 1 ... 847 (nil for supplement)
    public let printedLabel: String?      // e.g. "4"
    public let kind: MushafPageKind
    public let title: String              // e.g. "Surah Al-Fatihah"
    public let sourceAssetId: String      // e.g. "004"
    public let sourceWidth: Int?          // e.g. 720
    public let sourceHeight: Int?         // e.g. 1057
    public let imagePath: String?         // relative path to bundle resource
    public let imageSha256: String?

    public init(
        id: String,
        editionId: String,
        navigationIndex: Int,
        quranOrdinal: Int?,
        printedLabel: String?,
        kind: MushafPageKind,
        title: String,
        sourceAssetId: String,
        sourceWidth: Int?,
        sourceHeight: Int?,
        imagePath: String?,
        imageSha256: String?
    ) {
        self.id = id
        self.editionId = editionId
        self.navigationIndex = navigationIndex
        self.quranOrdinal = quranOrdinal
        self.printedLabel = printedLabel
        self.kind = kind
        self.title = title
        self.sourceAssetId = sourceAssetId
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
        self.imagePath = imagePath
        self.imageSha256 = imageSha256
    }
}

// MARK: - Page Verse Membership
public struct PageVerseMembership: Hashable, Sendable {
    public let verseKey: VerseKey
    public let readingOrder: Int
    public let startsHere: Bool
    public let endsHere: Bool

    public init(
        verseKey: VerseKey,
        readingOrder: Int,
        startsHere: Bool,
        endsHere: Bool
    ) {
        self.verseKey = verseKey
        self.readingOrder = readingOrder
        self.startsHere = startsHere
        self.endsHere = endsHere
    }
}

// MARK: - Full Page Content (Summary + Memberships + Regions)
public struct MushafPageContent: Hashable, Sendable {
    public let summary: MushafPageSummary
    public let verses: [PageVerseMembership]
    public let regions: [MushafRegion]

    public init(
        summary: MushafPageSummary,
        verses: [PageVerseMembership],
        regions: [MushafRegion]
    ) {
        self.summary = summary
        self.verses = verses
        self.regions = regions
    }

    /// Returns all region rectangles associated with the given verse key on this page.
    public func regions(for verse: VerseKey) -> [MushafRegion] {
        return regions.filter { $0.verseKey == verse }
    }
}

// MARK: - Mushaf Edition
public struct MushafEdition: Identifiable, Hashable, Sendable {
    public let id: String                 // "taj-company-13-847" or "legacy-qudratullah-13-849"
    public let contentVersion: Int
    public let displayName: String
    public let publisher: String
    public let rendererKind: RendererKind
    public let approvalStatus: ApprovalStatus
    public let quranPageCount: Int        // 847
    public let navigationPageCount: Int   // 848
    public let noticePath: String?

    public enum RendererKind: String, Sendable {
        case facsimile
        case legacyText
    }

    public enum ApprovalStatus: String, Sendable {
        case approved
        case unapproved
        case fixture
    }

    public init(
        id: String,
        contentVersion: Int,
        displayName: String,
        publisher: String,
        rendererKind: RendererKind,
        approvalStatus: ApprovalStatus,
        quranPageCount: Int,
        navigationPageCount: Int,
        noticePath: String?
    ) {
        self.id = id
        self.contentVersion = contentVersion
        self.displayName = displayName
        self.publisher = publisher
        self.rendererKind = rendererKind
        self.approvalStatus = approvalStatus
        self.quranPageCount = quranPageCount
        self.navigationPageCount = navigationPageCount
        self.noticePath = noticePath
    }
}
