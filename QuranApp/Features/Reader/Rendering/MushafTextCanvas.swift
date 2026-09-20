//
//  MushafTextCanvas.swift
//  QuranApp
//
//  Low-level native bridge only: glyph drawing and location-aware gestures.
//  Navigation, page decorations, chrome, and sheets remain SwiftUI.
//

import SwiftUI
import CoreText
import UIKit

@MainActor
struct MushafTextCanvas: UIViewRepresentable {
    let lines: [MushafLine]
    let grid: MushafPageGrid
    let selectedVerseKey: String?
    let palette: ThemePalette
    let onTap: () -> Void
    let onSelectAyah: (MushafWord) -> Void

    func makeUIView(context: Context) -> MushafCanvasView {
        MushafCanvasView(frame: .zero)
    }

    func updateUIView(_ view: MushafCanvasView, context: Context) {
        view.configure(
            lines: lines, grid: grid, selectedVerseKey: selectedVerseKey,
            palette: palette, onTap: onTap, onSelectAyah: onSelectAyah
        )
    }
}

@MainActor
final class MushafCanvasView: UIView, UIGestureRecognizerDelegate {
    private let engine = MushafTextLayoutEngine()
    private let ruleLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()
    private let glyphView = MushafGlyphView(frame: .zero)
    private let errorLabel = UILabel()
    private let haptic = UISelectionFeedbackGenerator()
    private var sourceLines: [MushafLine] = []
    private var cachedGrid: MushafPageGrid?
    private var selectedKey: String?
    private var onTap: (() -> Void)?
    private var onSelectAyah: ((MushafWord) -> Void)?
    private var verseElements: [MushafAyahAccessibilityElement] = []

    // Internal read-only diagnostics are exercised by native tests.
    private(set) var pageLayout: MushafPageLayout?
    private(set) var layoutBuildCount = 0
    private(set) var renderingError: Error?
    let holdRecognizer = UILongPressGestureRecognizer()
    let tapRecognizer = UITapGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight // Coordinates, not Arabic bidi.

        layer.addSublayer(ruleLayer)
        layer.addSublayer(highlightLayer)
        addSubview(glyphView) // Ink is above the glaze, never tinted by it.
        glyphView.isUserInteractionEnabled = false
        glyphView.accessibilityElementsHidden = true

        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.isHidden = true
        addSubview(errorLabel)

        holdRecognizer.addTarget(self, action: #selector(held(_:)))
        holdRecognizer.minimumPressDuration = 0.4
        holdRecognizer.allowableMovement = 10
        holdRecognizer.delegate = self
        addGestureRecognizer(holdRecognizer)

        tapRecognizer.addTarget(self, action: #selector(tapped(_:)))
        tapRecognizer.delegate = self
        tapRecognizer.require(toFail: holdRecognizer)
        addGestureRecognizer(tapRecognizer)
    }

    required init?(coder: NSCoder) { return nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView {
                tapRecognizer.require(toFail: scroll.panGestureRecognizer)
            }
            ancestor = view.superview
        }
        // Deliberately never make the pager wait for the long press to fail.
        // Movement can start native paging immediately, before the hold timeout.
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ruleLayer.frame = bounds
        highlightLayer.frame = bounds
        glyphView.frame = bounds
        errorLabel.frame = bounds.insetBy(dx: 20, dy: 20)
        CATransaction.commit()
    }

    func configure(
        lines: [MushafLine], grid: MushafPageGrid, selectedVerseKey: String?,
        palette: ThemePalette, onTap: @escaping () -> Void,
        onSelectAyah: @escaping (MushafWord) -> Void
    ) {
        self.onTap = onTap
        self.onSelectAyah = onSelectAyah
        let geometryChanged = lines != sourceLines || grid != cachedGrid
        if geometryChanged {
            sourceLines = lines
            cachedGrid = grid
            renderingError = nil
            // A transient zero/tiny layout pass (before the page has a real size)
            // must not be reported as a rendering failure.
            if lines.isEmpty || grid.size.width < 60 || grid.size.height < 200 {
                pageLayout = nil
            } else {
                do {
                    pageLayout = try engine.layout(lines: lines, grid: grid)
                    layoutBuildCount += 1
                } catch {
                    pageLayout = nil
                    renderingError = error
                }
            }
            let rules = CGMutablePath()
            for rect in grid.ruleRects { rules.addRect(rect) }
            ruleLayer.path = rules
            glyphView.pageLayout = pageLayout
            glyphView.contentScaleFactor = grid.displayScale
            glyphView.setNeedsDisplay()
            rebuildAccessibility()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ruleLayer.fillColor = UIColor(palette.borderSepia).withAlphaComponent(0.75).cgColor
        highlightLayer.fillColor = UIColor(palette.ayahHighlightGlaze).cgColor
        CATransaction.commit()
        glyphView.setColors(ink: UIColor(palette.inkUmber), accent: UIColor(palette.saddleAmber))
        errorLabel.textColor = UIColor(palette.inkUmber)
        errorLabel.text = renderingError.map { "Unable to display this page safely.\n\n\($0.localizedDescription)" }
        errorLabel.isHidden = renderingError == nil
        if renderingError != nil { accessibilityElements = [errorLabel] }
        updateSelection(selectedVerseKey, animate: !geometryChanged)
        setNeedsLayout()
    }

    private func updateSelection(_ key: String?, animate: Bool) {
        let changed = key != selectedKey
        selectedKey = key
        let path = CGMutablePath()
        if let key, let pageLayout {
            for fragment in pageLayout.fragments(for: key) {
                path.addRoundedRect(in: fragment.rect, cornerWidth: 2, cornerHeight: 2)
            }
        }
        let previousOpacity = highlightLayer.presentation()?.opacity ?? 0.55
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightLayer.path = path
        highlightLayer.opacity = 1
        CATransaction.commit()
        if changed {
            highlightLayer.removeAnimation(forKey: "selection")
            if key != nil, animate, !UIAccessibility.isReduceMotionEnabled {
                let spring = CASpringAnimation(keyPath: "opacity")
                spring.fromValue = max(0.55, previousOpacity)
                spring.toValue = 1
                spring.mass = 1
                spring.stiffness = 350
                spring.damping = 30
                spring.duration = spring.settlingDuration
                highlightLayer.add(spring, forKey: "selection")
            }
            for element in verseElements {
                element.accessibilityTraits = element.verseKey == key ? [.button, .selected] : [.button]
            }
        }
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onTap?()
    }

    @objc private func held(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let word = pageLayout?.word(at: recognizer.location(in: self)) else { return }
        activate(word)
    }

    private func activate(_ word: MushafWord) {
        // Synchronous feedback: neither shaping nor a database await is on the
        // recognition path. The view model takes over the same key immediately.
        updateSelection(word.verseKey, animate: true)
        haptic.selectionChanged()
        onSelectAyah?(word)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === holdRecognizer else { return true }
        var ancestor = superview
        while let view = ancestor {
            if let scroll = view as? UIScrollView, scroll.isDragging || scroll.isDecelerating {
                return false
            }
            ancestor = view.superview
        }
        return pageLayout?.word(at: gestureRecognizer.location(in: self)) != nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === holdRecognizer { haptic.prepare() }
        return true
    }

    private func rebuildAccessibility() {
        verseElements = []
        guard let pageLayout else {
            accessibilityElements = []
            return
        }
        var seen = Set<String>()
        // Logical source order, not the left-to-right visual hit-region order.
        for line in sourceLines.sorted(by: { $0.lineNumber < $1.lineNumber }) {
            for word in line.words where seen.insert(word.verseKey).inserted {
                let element = MushafAyahAccessibilityElement(accessibilityContainer: self)
                element.verseKey = word.verseKey
                element.accessibilityIdentifier = "ayah-\(word.verseKey)"
                element.accessibilityLabel = "Surah \(word.surah), Ayah \(word.ayah)"
                element.accessibilityHint = "Opens verse options and translation"
                element.accessibilityTraits = [.button]
                element.accessibilityFrameInContainerSpace = pageLayout.fragments(for: word.verseKey)
                    .reduce(CGRect.null) { $0.union($1.rect) }
                element.onActivate = { [weak self] in self?.activate(word) }
                element.accessibilityCustomActions = [
                    UIAccessibilityCustomAction(name: "Show or hide reading controls") { [weak self] _ in
                        self?.onTap?()
                        return self != nil
                    }
                ]
                verseElements.append(element)
            }
        }
        accessibilityElements = verseElements
    }
}

@MainActor
private final class MushafAyahAccessibilityElement: UIAccessibilityElement {
    var verseKey = ""
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        onActivate?()
        return onActivate != nil
    }
}

@MainActor
private final class MushafGlyphView: UIView {
    var pageLayout: MushafPageLayout?
    private var ink: UIColor = .label
    private var accent: UIColor = .secondaryLabel

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { return nil }

    func setColors(ink: UIColor, accent: UIColor) {
        guard self.ink != ink || self.accent != accent else { return }
        self.ink = ink
        self.accent = accent
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let pageLayout else { return }
        context.textMatrix = .identity
        for line in pageLayout.lines {
            context.saveGState()
            context.translateBy(x: 0, y: line.baseline)
            context.scaleBy(x: 1, y: -1)
            context.setFillColor((line.source.lineType == .bismillah ? accent : ink).cgColor)
            CTFontDrawGlyphs(line.font, line.glyphs, line.positions, line.glyphs.count, context)
            context.restoreGState()
        }
    }
}
