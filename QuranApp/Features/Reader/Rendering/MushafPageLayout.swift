//
//  MushafPageLayout.swift
//  QuranApp
//
//  Value-only coordinates and source ownership. No text normalization, wrapping,
//  or independently measured SwiftUI word views are permitted in the Mushaf.
//

import Foundation
import CoreGraphics

struct MushafPageGrid: Equatable, Sendable {
    static let rowCount = 13
    static let textInset: CGFloat = 4
    static let inkInset: CGFloat = 2.5

    let size: CGSize
    let displayScale: CGFloat

    init(size: CGSize, displayScale: CGFloat) {
        self.size = CGSize(width: max(0, size.width), height: max(0, size.height))
        self.displayScale = max(1, displayScale)
    }

    var bounds: CGRect { CGRect(origin: .zero, size: size) }
    var ruleThickness: CGFloat { max(0.75, 1 / displayScale) }

    /// Round each absolute boundary, not a row height that accumulates rounding error.
    func boundary(_ index: Int) -> CGFloat {
        if index == 0 { return 0 }
        if index == Self.rowCount { return size.height }
        return (size.height * CGFloat(index) / CGFloat(Self.rowCount) * displayScale).rounded() / displayScale
    }

    func rowRect(_ lineNumber: Int) -> CGRect {
        guard (1...Self.rowCount).contains(lineNumber) else { return .zero }
        let top = boundary(lineNumber - 1)
        return CGRect(x: 0, y: top, width: size.width, height: boundary(lineNumber) - top)
    }

    func textRect(_ lineNumber: Int) -> CGRect {
        rowRect(lineNumber).insetBy(dx: Self.textInset, dy: Self.inkInset)
    }

    /// Filled one-pixel rules avoid half-pixel stroke blur and include row 13.
    var ruleRects: [CGRect] {
        (1...Self.rowCount).map { index in
            CGRect(x: 0, y: boundary(index) - ruleThickness, width: size.width, height: ruleThickness)
        }
    }
}

struct MushafWordSpan: Equatable, Sendable {
    let word: MushafWord
    let range: NSRange
}

struct MushafTextSource: Sendable {
    let text: String
    let spans: [MushafWordSpan]

    init(line: MushafLine) throws {
        text = line.textIndopak
        guard line.lineType == .ayahText else {
            spans = []
            return
        }

        var reconstructed = ""
        var ranges: [MushafWordSpan] = []
        var locations = Set<String>()
        var offset = 0
        for word in line.words {
            guard !word.text.isEmpty, word.surah > 0, word.ayah > 0, word.word > 0,
                  word.location == "\(word.surah):\(word.ayah):\(word.word)",
                  locations.insert(word.location).inserted else {
                throw MushafLayoutError.invalidWord(word.location)
            }
            if !reconstructed.isEmpty {
                reconstructed.append(" ")
                offset += 1
            }
            let length = word.text.utf16.count
            ranges.append(MushafWordSpan(word: word, range: NSRange(location: offset, length: length)))
            reconstructed.append(word.text)
            offset += length
        }

        // String equality is canonically equivalent in Swift. Compare UTF-16 to
        // reject even normalization changes: offsets must describe the exact source.
        guard reconstructed.utf16.elementsEqual(text.utf16) else {
            throw MushafLayoutError.sourceMismatch(page: line.pageNumber, line: line.lineNumber)
        }
        spans = ranges
    }
}

struct MushafWordRegion: Sendable {
    let word: MushafWord
    let sourceRange: NSRange
    let inkBounds: CGRect
    let hitBounds: CGRect
}

struct MushafVerseFragment: Sendable {
    let verseKey: String
    let lineNumber: Int
    let rect: CGRect
}

enum MushafLayoutError: Error, LocalizedError {
    case invalidPage
    case invalidSize
    case invalidWord(String)
    case sourceMismatch(page: Int, line: Int)
    case unavailableFont(String)
    case missingGlyph(page: Int, line: Int)
    case unmappedWord(String)
    case cannotFit(page: Int, line: Int)

    var errorDescription: String? {
        switch self {
        case .invalidPage:
            return "The source page does not contain thirteen unique, numbered rows."
        case .invalidSize:
            return "The reading area is too small to lay out this page."
        case .invalidWord(let location):
            return "Invalid source word at \(location)."
        case .sourceMismatch(let page, let line):
            return "Word ownership differs from the source on page \(page), row \(line)."
        case .unavailableFont(let name):
            return "The required Quran font is unavailable (\(name))."
        case .missingGlyph(let page, let line):
            return "The Quran font could not shape page \(page), row \(line)."
        case .unmappedWord(let location):
            return "No selectable glyph geometry was found for \(location)."
        case .cannotFit(let page, let line):
            return "Text cannot fit safely on page \(page), row \(line)."
        }
    }
}
