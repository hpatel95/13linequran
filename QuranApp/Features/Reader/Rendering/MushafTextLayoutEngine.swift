//
//  MushafTextLayoutEngine.swift
//  QuranApp
//
//  One shaped stream per physical row. Its final glyph positions are the sole
//  authority for drawing, word hit regions, and multi-row Ayah highlights.
//  Core Text objects stay on the main actor; they never cross actor boundaries.
//

import CoreText
import UIKit

@MainActor
struct MushafRenderedLine {
    let source: MushafLine
    let font: CTFont
    let fontSize: CGFloat
    let glyphs: [CGGlyph]
    /// Core Text coordinates: absolute page x, baseline-relative y pointing up.
    let positions: [CGPoint]
    let baseline: CGFloat
    /// UIKit/page coordinates: y pointing down.
    let inkBounds: CGRect
    let words: [MushafWordRegion]
    let fragments: [MushafVerseFragment]
    let usedSpacingFallback: Bool
    let additionalGap: CGFloat
}

@MainActor
struct MushafPageLayout {
    let grid: MushafPageGrid
    let lines: [MushafRenderedLine]

    func word(at point: CGPoint) -> MushafWord? {
        guard grid.bounds.contains(point) else { return nil }
        for line in lines where grid.rowRect(line.source.lineNumber).contains(point) {
            return line.words.first(where: { $0.hitBounds.contains(point) })?.word
        }
        return nil
    }

    func fragments(for verseKey: String) -> [MushafVerseFragment] {
        lines.flatMap { $0.fragments.filter { $0.verseKey == verseKey } }
    }
}

@MainActor
final class MushafTextLayoutEngine {
    static let fontName = "AlQuranIndoPakbyQuranWBW"

    func layout(lines: [MushafLine], grid: MushafPageGrid) throws -> MushafPageLayout {
        guard lines.count == MushafPageGrid.rowCount,
              Set(lines.map(\.lineNumber)) == Set(1...MushafPageGrid.rowCount),
              Set(lines.map(\.pageNumber)).count == 1 else {
            throw MushafLayoutError.invalidPage
        }
        guard grid.size.width > 40, grid.size.height > 13 * 12 else {
            throw MushafLayoutError.invalidSize
        }

        var textRows: [(MushafLine, MushafTextSource)] = []
        for line in lines.sorted(by: { $0.lineNumber < $1.lineNumber }) {
            let source = try MushafTextSource(line: line)
            // Headers are SwiftUI decorations in this same grid. Empty canonical
            // slots are still ruled, but must never become selectable text.
            guard line.lineType != .surahName, !source.text.isEmpty else { continue }
            textRows.append((line, source))
        }

        // Determine a unified page font size based on the densest row on the page.
        // This ensures stroke weight and character sizing are 100% uniform across all rows.
        let referenceSize: CGFloat = 32
        var minFitSize: CGFloat = .greatestFiniteMagnitude

        for (row, source) in textRows where !row.isCentered && row.lineType != .bismillah {
            let target = grid.textRect(row.lineNumber)
            let reference = try shape(source, size: referenceSize, row: row)
            guard !reference.ink.isNull, reference.ink.width > 0, reference.ink.height > 0 else {
                throw MushafLayoutError.cannotFit(page: row.pageNumber, line: row.lineNumber)
            }
            let preferredSize = target.width / 13
            let rowFit = min(
                preferredSize * 1.18,
                referenceSize * target.width / reference.ink.width,
                referenceSize * target.height / reference.ink.height
            ) * 0.995
            if rowFit < minFitSize {
                minFitSize = rowFit
            }
        }

        let unifiedFontSize = minFitSize < .greatestFiniteMagnitude ? max(10, minFitSize) : (grid.textRect(1).width / 13)

        var rendered: [MushafRenderedLine] = []
        for (line, source) in textRows {
            rendered.append(try render(line, source: source, grid: grid, unifiedFontSize: unifiedFontSize))
        }
        return MushafPageLayout(grid: grid, lines: rendered)
    }

    private struct Glyph {
        let code: CGGlyph
        let stringIndex: Int
        let wordIndex: Int?
        let bounds: CGRect
        var position: CGPoint

        var ink: CGRect {
            bounds.isEmpty ? .null : bounds.offsetBy(dx: position.x, dy: position.y)
        }
    }

    private struct Shape {
        let line: CTLine
        let font: CTFont
        var glyphs: [Glyph]

        var ink: CGRect {
            glyphs.reduce(CGRect.null) { $0.union($1.ink) }
        }
    }

    private func shape(_ source: MushafTextSource, size: CGFloat, row: MushafLine) throws -> Shape {
        let font = CTFontCreateWithName(Self.fontName as CFString, size, nil)
        guard CTFontCopyPostScriptName(font) as String == Self.fontName else {
            throw MushafLayoutError.unavailableFont(Self.fontName)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.baseWritingDirection = .rightToLeft
        let text = NSAttributedString(string: source.text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            .paragraphStyle: paragraph,
            NSAttributedString.Key(kCTLanguageAttributeName as String): "ar"
        ])
        let line = CTLineCreateWithAttributedString(text)
        return Shape(line: line, font: font, glyphs: try extract(line, source: source, row: row))
    }

    private func extract(_ line: CTLine, source: MushafTextSource, row: MushafLine) throws -> [Glyph] {
        var result: [Glyph] = []
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let fontAttributeKey = kCTFontAttributeName as String
            let font = attributes[fontAttributeKey] as! CTFont
            // Silent fallback is unsafe: most verse ornaments are private-use.
            guard CTFontCopyPostScriptName(font) as String == Self.fontName else {
                throw MushafLayoutError.unavailableFont(CTFontCopyPostScriptName(font) as String)
            }
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            var bounds = [CGRect](repeating: .zero, count: count)
            let all = CFRange(location: 0, length: 0)
            CTRunGetGlyphs(run, all, &glyphs)
            CTRunGetPositions(run, all, &positions)
            CTRunGetStringIndices(run, all, &indices)
            CTFontGetBoundingRectsForGlyphs(font, .horizontal, glyphs, &bounds, count)

            for index in 0..<count {
                guard glyphs[index] != 0 else {
                    throw MushafLayoutError.missingGlyph(page: row.pageNumber, line: row.lineNumber)
                }
                // Indices are UTF-16 cluster starts; do not assume visual runs or
                // combining marks have monotonically increasing string indices.
                let owner = source.spans.firstIndex { NSLocationInRange(indices[index], $0.range) }
                result.append(Glyph(
                    code: glyphs[index], stringIndex: indices[index], wordIndex: owner,
                    bounds: bounds[index], position: positions[index]
                ))
            }
        }
        return result
    }

    private func render(_ row: MushafLine, source: MushafTextSource, grid: MushafPageGrid, unifiedFontSize: CGFloat) throws -> MushafRenderedLine {
        let target = grid.textRect(row.lineNumber)
        let centered = row.isCentered || row.lineType == .bismillah
        var fontSize = centered ? min(unifiedFontSize, target.width / 13) : unifiedFontSize

        // Native Arabic justification can change glyphs. Recheck vertical ink
        // after justification rather than relying only on the unexpanded line.
        for _ in 0..<3 {
            var shaped = try shape(source, size: fontSize, row: row)
            var usedFallback = false
            var extraGap: CGFloat = 0
            if !centered {
                let natural = shaped
                let naturalAdvance = CGFloat(CTLineGetTypographicBounds(shaped.line, nil, nil, nil))
                let targetAdvance = naturalAdvance + target.width - shaped.ink.width
                if let justified = CTLineCreateJustifiedLine(shaped.line, 1, Double(targetAdvance)) {
                    shaped.glyphs = try extract(justified, source: source, row: row)
                }
                // A forced final-line request is not guaranteed to fill the line.
                // If native justification overshoots, fall back to natural shaping,
                // never squeeze glyphs or compensate by clipping into the border.
                if shaped.ink.width > target.width + 0.01 {
                    shaped = natural
                }
                // Expand only if a residual gap remains, and re-measure between
                // passes so the extreme glyph really lands on the frame edge.
                var passes = 0
                while target.width - shaped.ink.width > 0.05 && passes < 3 {
                    extraGap = try distribute(target.width - shaped.ink.width, in: &shaped, source: source, row: row)
                    usedFallback = true
                    passes += 1
                }
            }

            let ink = shaped.ink
            if ink.height > target.height + 0.01 {
                fontSize *= target.height / ink.height * 0.995
                continue
            }
            // Overflow is never acceptable. A sub-pixel residual gap is tolerated
            // rather than blanking a page of scripture; the audited pages are also
            // asserted to be flush in the native test suite.
            guard ink.width <= target.width + 0.1,
                  centered || target.width - ink.width < 0.75 else {
                throw MushafLayoutError.cannotFit(page: row.pageNumber, line: row.lineNumber)
            }

            let originX = (centered ? target.midX - ink.width / 2 : target.minX) - ink.minX
            let baseline = target.midY + ink.midY
            let pageInk = CGRect(x: ink.minX + originX, y: baseline - ink.maxY, width: ink.width, height: ink.height)
            let regions = try wordRegions(
                shaped.glyphs, source: source, grid: grid, row: row,
                originX: originX, baseline: baseline, pageInk: pageInk
            )
            let fragments = verseFragments(regions, row: row, pageInk: pageInk, grid: grid)
            return MushafRenderedLine(
                source: row, font: shaped.font, fontSize: fontSize,
                glyphs: shaped.glyphs.map(\.code),
                positions: shaped.glyphs.map { CGPoint(x: $0.position.x + originX, y: $0.position.y) },
                baseline: baseline, inkBounds: pageInk, words: regions, fragments: fragments,
                usedSpacingFallback: usedFallback, additionalGap: extraGap
            )
        }
        throw MushafLayoutError.cannotFit(page: row.pageNumber, line: row.lineNumber)
    }

    /// Move complete, already-shaped word groups. All cursive/mark positioning
    /// within a group stays intact. Marker-only tokens stay attached to the
    /// preceding lexical word. The source string and its offsets never change.
    /// Groups are ordered by their visual centre, so expansion follows the actual
    /// left-to-right visual gaps rather than the logical RTL word order.
    private func distribute(_ remainder: CGFloat, in shape: inout Shape, source: MushafTextSource, row: MushafLine) throws -> CGFloat {
        var groupForWord: [Int] = []
        var group = -1
        for span in source.spans {
            if group < 0 || span.word.text.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) {
                group += 1
            }
            groupForWord.append(group)
        }

        var bounds: [Int: CGRect] = [:]
        for glyph in shape.glyphs {
            guard let word = glyph.wordIndex, !glyph.ink.isNull else { continue }
            let groupID = groupForWord[word]
            bounds[groupID] = (bounds[groupID] ?? .null).union(glyph.ink)
        }
        let visualGroups = bounds.keys.sorted { bounds[$0]!.midX < bounds[$1]!.midX }
        guard visualGroups.count >= 2 else {
            throw MushafLayoutError.cannotFit(page: row.pageNumber, line: row.lineNumber)
        }

        let lastRank = visualGroups.count - 1
        let ranks = Dictionary(uniqueKeysWithValues: visualGroups.enumerated().map { ($0.element, $0.offset) })
        for index in shape.glyphs.indices {
            let glyph = shape.glyphs[index]
            // Separator spaces have no ink but must travel with their neighbour.
            let owner = glyph.wordIndex ?? source.spans.lastIndex(where: { $0.range.location <= glyph.stringIndex })
            guard let owner, let rank = ranks[groupForWord[owner]] else { continue }
            shape.glyphs[index].position.x += remainder * CGFloat(rank) / CGFloat(lastRank)
        }
        return remainder / CGFloat(lastRank)
    }

    private func wordRegions(
        _ glyphs: [Glyph], source: MushafTextSource, grid: MushafPageGrid,
        row: MushafLine, originX: CGFloat, baseline: CGFloat, pageInk: CGRect
    ) throws -> [MushafWordRegion] {
        var bounds: [Int: CGRect] = [:]
        for glyph in glyphs {
            guard let word = glyph.wordIndex, !glyph.ink.isNull else { continue }
            let ink = glyph.ink
            let rect = CGRect(x: ink.minX + originX, y: baseline - ink.maxY, width: ink.width, height: ink.height)
            bounds[word] = (bounds[word] ?? .null).union(rect)
        }
        for index in source.spans.indices where bounds[index] == nil {
            throw MushafLayoutError.unmappedWord(source.spans[index].word.location)
        }
        // A token may span multiple bidi/font runs. Union its actual glyph ink,
        // then partition the intervening whitespace at shared boundaries.
        let order = bounds.keys.sorted { bounds[$0]!.midX < bounds[$1]!.midX }
        let rowRect = grid.rowRect(row.lineNumber)
        let textRect = grid.textRect(row.lineNumber)
        var regions: [MushafWordRegion] = []
        for (rank, index) in order.enumerated() {
            let ink = bounds[index]!
            let left = rank == 0 ? max(textRect.minX, pageInk.minX - 3)
                : (bounds[order[rank - 1]]!.maxX + ink.minX) / 2
            let right = rank == order.count - 1 ? min(textRect.maxX, pageInk.maxX + 3)
                : (ink.maxX + bounds[order[rank + 1]]!.minX) / 2
            guard right > left else { throw MushafLayoutError.unmappedWord(source.spans[index].word.location) }
            regions.append(MushafWordRegion(
                word: source.spans[index].word, sourceRange: source.spans[index].range, inkBounds: ink,
                hitBounds: CGRect(x: left, y: rowRect.minY, width: right - left, height: rowRect.height)
            ))
        }
        return regions
    }

    private func verseFragments(_ regions: [MushafWordRegion], row: MushafLine, pageInk: CGRect, grid: MushafPageGrid) -> [MushafVerseFragment] {
        let band = pageInk.insetBy(dx: 0, dy: -2).intersection(grid.rowRect(row.lineNumber).insetBy(dx: 0, dy: 1))
        var fragments: [MushafVerseFragment] = []
        // Merge only visually adjacent owners. Never bridge over another Ayah,
        // even when logical order differs from visual order around PUA markers.
        for region in regions {
            let rect = CGRect(x: region.hitBounds.minX, y: band.minY, width: region.hitBounds.width, height: band.height)
            if let previous = fragments.last, previous.verseKey == region.word.verseKey {
                fragments[fragments.count - 1] = MushafVerseFragment(
                    verseKey: previous.verseKey, lineNumber: row.lineNumber, rect: previous.rect.union(rect)
                )
            } else {
                fragments.append(MushafVerseFragment(verseKey: region.word.verseKey, lineNumber: row.lineNumber, rect: rect))
            }
        }
        return fragments
    }
}
