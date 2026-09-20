//
//  MushafLayoutTests.swift
//  QuranAppTests
//
//  Native verification of the shared drawing/hit-testing geometry that replaced
//  the SwiftUI `Text` line renderer. Each acceptance failure from the physical
//  Test 1 build is encoded as an assertion here.
//

import XCTest
import CoreText
import UIKit
@testable import QuranApp

@MainActor
final class MushafLayoutTests: XCTestCase {
    private var repository: QuranDatabaseService!
    private let engine = MushafTextLayoutEngine()

    /// Pages chosen to cover: Surah header + blank slots (1, 2), dense text (4),
    /// a mixed two-Ayah row with a continuation (28), a centered row (105),
    /// a Surah transition mid-page (610, 849), and a plain interior page (613).
    private let auditedPages = [1, 2, 4, 28, 105, 610, 613, 849]

    override func setUp() async throws {
        try await super.setUp()
        Self.registerFontIfNeeded()
        repository = try QuranDatabaseService(databaseURL: Self.databaseURL())
    }

    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }

    // MARK: - Environment helpers

    private static func databaseURL() throws -> URL {
        if let bundled = Bundle.main.path(forResource: "quran_content", ofType: "sqlite") {
            return URL(fileURLWithPath: bundled)
        }
        let relative = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("QuranApp/Resources/Database/quran_content.sqlite")
        guard FileManager.default.fileExists(atPath: relative.path) else {
            throw XCTSkip("Bundled Quran database is unavailable in this test environment.")
        }
        return relative
    }

    private static func registerFontIfNeeded() {
        let probe = CTFontCreateWithName(MushafTextLayoutEngine.fontName as CFString, 12, nil)
        guard CTFontCopyPostScriptName(probe) as String != MushafTextLayoutEngine.fontName else { return }
        var candidates: [URL] = []
        if let bundled = Bundle.main.url(forResource: "IndoPak-Nastaleeq", withExtension: "ttf") {
            candidates.append(bundled)
        }
        candidates.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("QuranApp/Resources/Fonts/IndoPak-Nastaleeq.ttf")
        )
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        let registered = CTFontCreateWithName(MushafTextLayoutEngine.fontName as CFString, 12, nil)
        XCTAssertEqual(
            CTFontCopyPostScriptName(registered) as String,
            MushafTextLayoutEngine.fontName,
            "The bundled Quran font must be registered before layout tests run."
        )
    }

    private func makeLayout(page: Int, size: CGSize = CGSize(width: 327, height: 520), scale: CGFloat = 3) async throws -> MushafPageLayout {
        let lines = try await repository.fetchLines(forPage: page)
        XCTAssertEqual(lines.count, 13, "Page \(page) must expose thirteen physical rows.")
        return try engine.layout(lines: lines, grid: MushafPageGrid(size: size, displayScale: scale))
    }

    private func pageLines(_ page: Int) async throws -> [MushafLine] {
        try await repository.fetchLines(forPage: page)
    }

    // MARK: - Grid geometry

    func testGridBoundariesArePixelAlignedAndTileExactly() {
        for size in [CGSize(width: 320, height: 452), CGSize(width: 327, height: 521), CGSize(width: 430, height: 700)] {
            let grid = MushafPageGrid(size: size, displayScale: 3)
            XCTAssertEqual(grid.boundary(0), 0, accuracy: 0.0001)
            XCTAssertEqual(grid.boundary(MushafPageGrid.rowCount), size.height, accuracy: 0.0001)
            for index in 0...MushafPageGrid.rowCount {
                let scaled = grid.boundary(index) * 3
                XCTAssertEqual(scaled, scaled.rounded(), accuracy: 0.0001, "Boundary \(index) must land on a device pixel.")
                if index > 0 {
                    XCTAssertGreaterThan(grid.boundary(index), grid.boundary(index - 1), "Rows must not collapse or invert.")
                }
            }
            // Every slot exists and the final rule closes the bottom of row 13.
            XCTAssertEqual(grid.ruleRects.count, MushafPageGrid.rowCount)
            XCTAssertEqual(grid.ruleRects.last!.maxY, size.height, accuracy: 0.0001)
            XCTAssertEqual(grid.ruleRects.first!.maxY, grid.boundary(1), accuracy: 0.0001)
            for rect in grid.ruleRects {
                XCTAssertGreaterThan(rect.width, 0)
                XCTAssertLessThanOrEqual(rect.maxY, size.height + 0.0001)
            }
            // Adjacent rows must not overlap or leave gaps.
            for row in 1..<MushafPageGrid.rowCount {
                XCTAssertEqual(grid.rowRect(row).maxY, grid.rowRect(row + 1).minY, accuracy: 0.0001)
            }
            XCTAssertGreaterThan(grid.textRect(1).height, 0)
        }
    }

    func testWordOwnershipRebuildsTheExactSourceText() async throws {
        for page in auditedPages {
            for line in try await pageLines(page) where line.lineType == .ayahText && !line.words.isEmpty {
                let source = try MushafTextSource(line: line)
                XCTAssertEqual(
                    source.text.utf16.count,
                    line.textIndopak.utf16.count,
                    "Page \(page) row \(line.lineNumber) ownership must describe the exact source."
                )
                var offset = 0
                for span in source.spans {
                    XCTAssertEqual(span.range.location, offset, "Word spans must tile from the start of the row.")
                    XCTAssertGreaterThan(span.range.length, 0, "No word token may own an empty range.")
                    offset = span.range.location + span.range.length
                    if span.word.location != line.words.last?.location {
                        offset += 1 // single preserved separator space
                    }
                }
                XCTAssertEqual(offset, line.textIndopak.utf16.count, "Spans plus separators must cover the row exactly.")
                XCTAssertEqual(
                    source.spans.map(\.word.location),
                    line.words.map(\.location),
                    "Ownership order must follow the canonical word order."
                )
            }
        }
    }

    func testHeaderAndBlankSlotsProduceNoSelectableGeometry() async throws {
        for page in [1, 2, 849] {
            let lines = try await pageLines(page)
            let blankRows = lines.filter { $0.words.isEmpty && $0.lineType == .ayahText }.map(\.lineNumber)
            XCTAssertFalse(blankRows.isEmpty, "Pages 1, 2 and 849 are expected to contain deliberately empty slots.")
            let layout = try await makeLayout(page: page)
            for line in layout.lines {
                XCTAssertFalse(blankRows.contains(line.source.lineNumber), "A blank slot must never render or accept touches.")
            }
            // Surah headers are SwiftUI cartouches, never Core Text lines.
            for header in lines.filter({ $0.lineType == .surahName }) {
                XCTAssertFalse(layout.lines.contains { $0.source.lineNumber == header.lineNumber })
            }
            let grid = layout.grid
            for row in blankRows {
                let rect = grid.rowRect(row)
                XCTAssertNil(
                    layout.word(at: CGPoint(x: rect.midX, y: rect.midY)),
                    "Touching an empty row must not resolve to any Ayah."
                )
            }
        }
    }

    func testTouchOutsideTheGridResolvesToNothing() async throws {
        let layout = try await makeLayout(page: 28)
        XCTAssertNil(layout.word(at: CGPoint(x: -5, y: 20)))
        XCTAssertNil(layout.word(at: CGPoint(x: 20, y: -5)))
        XCTAssertNil(layout.word(at: CGPoint(x: 20, y: layout.grid.size.height + 10)))
    }

    // MARK: - Justification (Test 1: uneven margins)

    func testEveryJustifiedRowFillsTheUsableWidthWithoutOverflow() async throws {
        for page in auditedPages {
            for size in [CGSize(width: 320, height: 452), CGSize(width: 327, height: 520), CGSize(width: 430, height: 700)] {
                let layout = try await makeLayout(page: page, size: size)
                for line in layout.lines where !line.source.isCentered && line.source.lineType != .bismillah {
                    let target = layout.grid.textRect(line.source.lineNumber)
                    XCTAssertEqual(
                        line.inkBounds.minX, target.minX, accuracy: 0.6,
                        "Page \(page) row \(line.source.lineNumber) must be flush with the leading frame edge."
                    )
                    XCTAssertEqual(
                        line.inkBounds.maxX, target.maxX, accuracy: 0.6,
                        "Page \(page) row \(line.source.lineNumber) must be flush with the trailing frame edge (no ragged right gap)."
                    )
                    XCTAssertLessThanOrEqual(
                        line.inkBounds.height, target.height + 0.5,
                        "Page \(page) row \(line.source.lineNumber) must not overflow its row rule."
                    )
                }
            }
        }
    }

    func testJustifiedRowsUseWholeWordGroupsRatherThanStretchedGlyphs() async throws {
        let layout = try await makeLayout(page: 28)
        for line in layout.lines {
            if line.usedSpacingFallback {
                XCTAssertGreaterThanOrEqual(line.additionalGap, 0, "Spacing fallback may never compress glyphs.")
            }
            // The font size must remain legible even when a row is expanded to the full width.
            XCTAssertGreaterThan(line.fontSize, 8, "Row \(line.source.lineNumber) font size collapsed below legibility.")
            XCTAssertLessThan(line.fontSize, 40, "Row \(line.source.lineNumber) font size exceeds the page scale.")
        }
    }

    func testCenteredRowsStayCenteredAndAreNeverStretchedToFill() async throws {
        let layout = try await makeLayout(page: 105)
        let centered = layout.lines.filter { $0.source.isCentered }
        XCTAssertFalse(centered.isEmpty, "Page 105 is expected to begin with a centered row.")
        for line in centered {
            let target = layout.grid.textRect(line.source.lineNumber)
            XCTAssertEqual(line.inkBounds.midX, target.midX, accuracy: 1.5, "Centered rows must remain optically centered.")
            XCTAssertLessThanOrEqual(line.inkBounds.width, target.width + 0.5)
            XCTAssertFalse(line.usedSpacingFallback, "A centered row must never be expanded to fill the row width.")
        }
        // Al-Fatihah 1:1 is a short centered Ayah row: it must not be spread edge to edge.
        let fatihah = try await makeLayout(page: 1)
        let ayahOneOne = fatihah.lines.first { $0.source.lineNumber == 2 }
        XCTAssertNotNil(ayahOneOne)
        if let line = ayahOneOne {
            XCTAssertLessThan(line.inkBounds.width, fatihah.grid.textRect(2).width - 2, "Short centered rows must keep natural width.")
        }
    }

    // MARK: - Selection (Test 1: whole-line / first-word selection)

    func testSharedRowResolvesEachAyahIndependently() async throws {
        let layout = try await makeLayout(page: 28)
        guard let mixed = layout.lines.first(where: { $0.source.lineNumber == 10 }) else {
            return XCTFail("Page 28 row 10 is expected to be present.")
        }
        let keys = Set(mixed.words.map(\.word.verseKey))
        XCTAssertEqual(keys, ["2:143", "2:144"], "Row 10 must carry the end of 2:143 and the start of 2:144.")

        let owners = mixed.words.filter { $0.word.verseKey == "2:143" }
        let successors = mixed.words.filter { $0.word.verseKey == "2:144" }
        XCTAssertFalse(owners.isEmpty)
        XCTAssertFalse(successors.isEmpty)

        // In RTL the earlier Ayah occupies the right side of the row.
        let ownerRight = owners.map(\.hitBounds.maxX).max()!
        let successorLeft = successors.map(\.hitBounds.minX).min()!
        XCTAssertGreaterThan(ownerRight, successorLeft, "2:143 must sit to the right of 2:144 on the same row.")
        XCTAssertLessThanOrEqual(
            successors.map(\.hitBounds.maxX).max()!,
            owners.map(\.hitBounds.minX).min()! + 0.6,
            "Hit regions of neighbouring Ayahs must not overlap on a shared row."
        )

        // The regression: the old renderer always selected `line.words.first`.
        XCTAssertEqual(mixed.words.first?.word.verseKey, "2:143")
        let leftmost = mixed.words.min { $0.hitBounds.minX < $1.hitBounds.minX }!
        XCTAssertEqual(leftmost.word.verseKey, "2:144", "The visually leftmost token of the shared row belongs to 2:144.")
        XCTAssertEqual(
            layout.word(at: CGPoint(x: leftmost.hitBounds.midX, y: leftmost.hitBounds.midY))?.verseKey,
            "2:144",
            "Touching the left side of a shared row must select 2:144, never the first word of the line."
        )
        let rightmost = mixed.words.max { $0.hitBounds.minX < $1.hitBounds.minX }!
        XCTAssertEqual(
            layout.word(at: CGPoint(x: rightmost.hitBounds.midX, y: rightmost.hitBounds.midY))?.verseKey,
            "2:143"
        )

        // Whole-row coverage: every horizontal sample inside the row resolves to one of the two Ayahs.
        let row = layout.grid.rowRect(10)
        var samples: Set<String> = []
        for step in 1..<20 {
            let x = row.minX + row.width * CGFloat(step) / 20
            guard let word = layout.word(at: CGPoint(x: x, y: row.midY)) else { continue }
            samples.insert(word.verseKey)
        }
        XCTAssertEqual(samples, ["2:143", "2:144"], "Both Ayahs must be reachable by touch across the shared row.")
    }

    func testHighlightFragmentsFollowTheAyahAcrossRowsOnly() async throws {
        // Al-Fatihah 1:7 continues across rows 6, 7 and 8.
        let fatihah = try await makeLayout(page: 1)
        let rows = Set(fatihah.fragments(for: "1:7").map(\.lineNumber))
        XCTAssertEqual(rows, [6, 7, 8], "A multi-row Ayah must highlight every one of its own fragments.")

        let oneSix = Set(fatihah.fragments(for: "1:6").map(\.lineNumber))
        XCTAssertEqual(oneSix, [6], "Row 6 also carries 1:6 and must highlight separately.")

        // Fragments must cover exactly the Ayah's own tokens and nothing else.
        let lines = try await pageLines(1)
        for key in ["1:1", "1:2", "1:3", "1:4", "1:5", "1:6", "1:7"] {
            let ownedRows = Set(lines.filter { line in line.words.contains { $0.verseKey == key } }.map(\.lineNumber))
            let fragmentRows = Set(fatihah.fragments(for: key).map(\.lineNumber))
            XCTAssertEqual(fragmentRows, ownedRows, "Fragments for \(key) must match its source rows exactly.")
        }
    }

    func testFragmentsDoNotLeakBetweenNeighbouringAyahsOnASharedRow() async throws {
        let layout = try await makeLayout(page: 28)
        let end = layout.fragments(for: "2:143").filter { $0.lineNumber == 10 }
        let start = layout.fragments(for: "2:144").filter { $0.lineNumber == 10 }
        XCTAssertEqual(end.count, 1, "2:143 must contribute exactly one fragment to the shared row.")
        XCTAssertEqual(start.count, 1, "2:144 must contribute exactly one fragment to the shared row.")
        XCTAssertLessThanOrEqual(
            start[0].rect.maxX, end[0].rect.minX + 0.6,
            "2:144's shared-row highlight must stop where 2:143's highlight begins."
        )
        XCTAssertGreaterThan(start[0].rect.width, 0)
        XCTAssertGreaterThan(end[0].rect.width, 0)
    }

    func testContinuationRowsResolveWithoutLeavingTheDisplayedPage() async throws {
        // 2:144 begins on page 28 and continues on page 29; its pageNumber metadata
        // points at page 28. Touch resolution must be driven by geometry alone.
        let layout = try await makeLayout(page: 28)
        let row = layout.grid.rowRect(13)
        let word = layout.word(at: CGPoint(x: row.midX, y: row.midY))
        XCTAssertEqual(word?.surah, 2)
        XCTAssertEqual(word?.ayah, 144)
        XCTAssertNotNil(layout.fragments(for: "2:144").first { $0.lineNumber == 13 })
    }

    func testEveryRenderedWordHasUsableHitAndInkGeometry() async throws {
        for page in auditedPages {
            let layout = try await makeLayout(page: page)
            for line in layout.lines {
                let row = layout.grid.rowRect(line.source.lineNumber)
                XCTAssertEqual(Set(line.words.map(\.word.location)), Set(line.source.words.map(\.location)),
                               "Page \(page) row \(line.source.lineNumber) lost word ownership during layout.")
                for region in line.words {
                    XCTAssertFalse(region.inkBounds.isNull, "\(region.word.location) has no ink geometry.")
                    XCTAssertFalse(region.inkBounds.isEmpty, "\(region.word.location) has empty ink geometry.")
                    XCTAssertGreaterThan(region.hitBounds.width, 0, "\(region.word.location) has no touchable width.")
                    XCTAssertEqual(region.hitBounds.minY, row.minY, accuracy: 0.6)
                    XCTAssertEqual(region.hitBounds.maxY, row.maxY, accuracy: 0.6)
                    XCTAssertTrue(row.insetBy(dx: -0.6, dy: -0.6).contains(region.inkBounds),
                                  "\(region.word.location) ink escaped its row rule.")
                }
            }
        }
    }

    func testLayoutIsStableAndDeterministicAcrossPages() async throws {
        let first = try await makeLayout(page: 610)
        let second = try await makeLayout(page: 610)
        XCTAssertEqual(first.lines.count, second.lines.count)
        for (a, b) in zip(first.lines, second.lines) {
            XCTAssertEqual(a.inkBounds.minX, b.inkBounds.minX, accuracy: 0.001)
            XCTAssertEqual(a.inkBounds.minY, b.inkBounds.minY, accuracy: 0.001)
            XCTAssertEqual(a.inkBounds.width, b.inkBounds.width, accuracy: 0.001)
            XCTAssertEqual(a.inkBounds.height, b.inkBounds.height, accuracy: 0.001)
            XCTAssertEqual(a.glyphs, b.glyphs)
        }
        // A Surah header mid-page (page 610 row 3) must not disturb neighbouring rows.
        XCTAssertFalse(first.lines.contains { $0.source.lineType == .surahName })
        XCTAssertTrue(first.lines.contains { $0.source.lineType == .bismillah })
    }

    func testDegenerateGeometryFailsLoudlyInsteadOfClipping() async throws {
        let lines = try await pageLines(28)
        XCTAssertThrowsError(try engine.layout(lines: lines, grid: MushafPageGrid(size: CGSize(width: 30, height: 40), displayScale: 2))) { error in
            XCTAssertTrue(error is MushafLayoutError)
        }
        XCTAssertThrowsError(try engine.layout(lines: Array(lines.prefix(12)), grid: MushafPageGrid(size: CGSize(width: 327, height: 520), displayScale: 3)))
    }

    func testSourceOwnershipRejectsNormalisationOrReordering() {
        let line = MushafLine(
            id: 0, pageNumber: 1, lineNumber: 1, lineType: .ayahText, surahId: nil, isCentered: false,
            textIndopak: "بِسْمِ اللَّهِ",
            words: [
                MushafWord(surah: 1, ayah: 1, word: 1, location: "1:1:1", text: "بِسْمِ"),
                MushafWord(surah: 1, ayah: 1, word: 2, location: "1:1:2", text: "اللَّهِ")
            ]
        )
        XCTAssertNoThrow(try MushafTextSource(line: line))

        let mutated = MushafLine(
            id: 0, pageNumber: 1, lineNumber: 1, lineType: .ayahText, surahId: nil, isCentered: false,
            textIndopak: "بِسْمِ اللَّه",
            words: line.words
        )
        XCTAssertThrowsError(try MushafTextSource(line: mutated), "Any divergence from the source text must be rejected.")

        let duplicated = MushafLine(
            id: 0, pageNumber: 1, lineNumber: 1, lineType: .ayahText, surahId: nil, isCentered: false,
            textIndopak: "بِسْمِ بِسْمِ",
            words: [
                MushafWord(surah: 1, ayah: 1, word: 1, location: "1:1:1", text: "بِسْمِ"),
                MushafWord(surah: 1, ayah: 1, word: 1, location: "1:1:1", text: "بِسْمِ")
            ]
        )
        XCTAssertThrowsError(try MushafTextSource(line: duplicated), "Duplicate word locations must be rejected.")
    }

    // MARK: - Page-wide summary

    func testAuditedPagesReportNoLayoutErrors() async throws {
        var renderedRows = 0
        var emptyRows = 0
        var centeredRows = 0
        for page in auditedPages {
            let lines = try await pageLines(page)
            let layout = try await makeLayout(page: page)
            renderedRows += layout.lines.count
            emptyRows += lines.filter { $0.lineType == .ayahText && $0.words.isEmpty }.count
            centeredRows += layout.lines.filter { $0.source.isCentered || $0.source.lineType == .bismillah }.count
        }
        XCTAssertGreaterThan(renderedRows, 40, "Audited pages should render the majority of their populated rows.")
        XCTAssertEqual(emptyRows, 15, "Pages 1, 2 and 849 each hold five deliberately empty slots.")
        XCTAssertGreaterThan(centeredRows, 0)
    }
}
