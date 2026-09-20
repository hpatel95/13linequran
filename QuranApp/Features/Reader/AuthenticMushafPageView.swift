//
//  AuthenticMushafPageView.swift
//  QuranApp
//
//  Authentic scanned lithograph page view with aspect-fit geometry,
//  interactive Ayah bounding-region hit testing, and glowing highlight glaze.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public struct AuthenticMushafPageView: View {
    public let summary: MushafPageSummary
    public let content: MushafPageContent?
    public let selectedVerse: VerseKey?
    public let playingVerse: VerseKey?
    public let palette: ThemePalette
    public let onSelectAyah: ((VerseKey) -> Void)?
    public let onToggleChrome: () -> Void

    #if canImport(UIKit)
    @State private var loadedImage: UIImage?
    #endif
    @State private var isLoadingImage: Bool = true

    public init(
        summary: MushafPageSummary,
        content: MushafPageContent? = nil,
        selectedVerse: VerseKey? = nil,
        playingVerse: VerseKey? = nil,
        palette: ThemePalette = AppColors.palette(for: .sepia),
        onSelectAyah: ((VerseKey) -> Void)? = nil,
        onToggleChrome: @escaping () -> Void = {}
    ) {
        self.summary = summary
        self.content = content
        self.selectedVerse = selectedVerse
        self.playingVerse = playingVerse
        self.palette = palette
        self.onSelectAyah = onSelectAyah
        self.onToggleChrome = onToggleChrome
    }

    public var body: some View {
        ZStack {
            palette.canvasVellum.ignoresSafeArea()

            #if canImport(UIKit)
            AuthenticMushafCanvasRepresentable(
                image: loadedImage,
                summary: summary,
                content: content,
                selectedVerse: selectedVerse,
                playingVerse: playingVerse,
                palette: palette,
                onSelectAyah: onSelectAyah,
                onToggleChrome: onToggleChrome
            )
            .ignoresSafeArea()

            if isLoadingImage && loadedImage == nil {
                ProgressView()
                    .tint(palette.saddleAmber)
            }
            #endif
        }
        .accessibilityIdentifier("authentic-page-\(summary.navigationIndex)")
        .task(id: summary.id) {
            await loadPageImage()
        }
    }

    private func loadPageImage() async {
        #if canImport(UIKit)
        isLoadingImage = true
        let image = await MushafImageLoader.shared.loadImage(for: summary)
        self.loadedImage = image
        self.isLoadingImage = false
        #endif
    }
}

// MARK: - Native UIKit Canvas & Gesture Bridge
#if canImport(UIKit)
struct AuthenticMushafCanvasRepresentable: UIViewRepresentable {
    let image: UIImage?
    let summary: MushafPageSummary
    let content: MushafPageContent?
    let selectedVerse: VerseKey?
    let playingVerse: VerseKey?
    let palette: ThemePalette
    let onSelectAyah: ((VerseKey) -> Void)?
    let onToggleChrome: () -> Void

    func makeUIView(context: Context) -> AuthenticMushafCanvasUIView {
        let view = AuthenticMushafCanvasUIView()
        view.configure(
            image: image,
            summary: summary,
            content: content,
            selectedVerse: selectedVerse,
            playingVerse: playingVerse,
            palette: palette,
            onSelectAyah: onSelectAyah,
            onToggleChrome: onToggleChrome
        )
        return view
    }

    func updateUIView(_ uiView: AuthenticMushafCanvasUIView, context: Context) {
        uiView.configure(
            image: image,
            summary: summary,
            content: content,
            selectedVerse: selectedVerse,
            playingVerse: playingVerse,
            palette: palette,
            onSelectAyah: onSelectAyah,
            onToggleChrome: onToggleChrome
        )
    }
}

final class AuthenticMushafCanvasUIView: UIView, UIGestureRecognizerDelegate {
    private let imageView = UIImageView()
    private let highlightLayer = CAShapeLayer()
    private let haptic = UISelectionFeedbackGenerator()

    private var summary: MushafPageSummary?
    private var content: MushafPageContent?
    private var selectedVerse: VerseKey?
    private var playingVerse: VerseKey?
    private var onSelectAyah: ((VerseKey) -> Void)?
    private var onToggleChrome: (() -> Void)?

    let holdRecognizer = UILongPressGestureRecognizer()
    let tapRecognizer = UITapGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isAccessibilityElement = false
        semanticContentAttribute = .forceLeftToRight

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.accessibilityElementsHidden = true
        addSubview(imageView)

        layer.addSublayer(highlightLayer)
        highlightLayer.fillColor = UIColor(red: 0.88, green: 0.65, blue: 0.15, alpha: 0.28).cgColor
        highlightLayer.strokeColor = UIColor(red: 0.88, green: 0.65, blue: 0.15, alpha: 0.60).cgColor
        highlightLayer.lineWidth = 1.2

        holdRecognizer.addTarget(self, action: #selector(handleHold(_:)))
        holdRecognizer.minimumPressDuration = 0.35
        holdRecognizer.allowableMovement = 15
        holdRecognizer.delegate = self
        addGestureRecognizer(holdRecognizer)

        tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        tapRecognizer.delegate = self
        tapRecognizer.require(toFail: holdRecognizer)
        addGestureRecognizer(tapRecognizer)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        updateHighlight()
        rebuildAccessibility()
    }

    func configure(
        image: UIImage?,
        summary: MushafPageSummary,
        content: MushafPageContent?,
        selectedVerse: VerseKey?,
        playingVerse: VerseKey?,
        palette: ThemePalette,
        onSelectAyah: ((VerseKey) -> Void)?,
        onToggleChrome: @escaping () -> Void
    ) {
        self.imageView.image = image
        self.summary = summary
        self.content = content
        self.selectedVerse = selectedVerse
        self.playingVerse = playingVerse
        self.onSelectAyah = onSelectAyah
        self.onToggleChrome = onToggleChrome

        updateHighlight()
        rebuildAccessibility()
    }

    private func currentGeometry() -> MushafImageGeometry {
        let imgSize: CGSize
        if let img = imageView.image {
            imgSize = img.size
        } else {
            imgSize = CGSize(width: summary?.sourceWidth ?? 720, height: summary?.sourceHeight ?? 1057)
        }
        return MushafImageGeometry(containerSize: bounds.size, imageSize: imgSize)
    }

    private func updateHighlight() {
        let active = playingVerse ?? selectedVerse
        guard let verse = active, let content = content, bounds.width > 0, bounds.height > 0 else {
            highlightLayer.path = nil
            return
        }

        let regions = content.regions(for: verse)
        guard !regions.isEmpty else {
            highlightLayer.path = nil
            return
        }

        let geo = currentGeometry()
        let path = CGMutablePath()
        for r in regions {
            let rect = geo.viewRect(for: r.rect)
            path.addRoundedRect(in: rect, cornerWidth: 4, cornerHeight: 4)
        }
        highlightLayer.path = path
    }

    private func rebuildAccessibility() {
        guard let content = content, bounds.width > 0, bounds.height > 0 else {
            accessibilityElements = []
            return
        }

        let geo = currentGeometry()
        var elements: [UIAccessibilityElement] = []

        for membership in content.verses {
            let key = membership.verseKey
            let regions = content.regions(for: key)
            guard !regions.isEmpty else { continue }

            var unionRect: CGRect = .null
            for r in regions {
                let rect = geo.viewRect(for: r.rect)
                unionRect = unionRect.isNull ? rect : unionRect.union(rect)
            }

            guard !unionRect.isNull else { continue }

            let el = MushafFacsimileAccessibilityElement(accessibilityContainer: self)
            el.verseKey = key
            el.accessibilityIdentifier = "ayah-\(key.surah):\(key.ayah)"
            el.accessibilityLabel = "Surah \(key.surah), Ayah \(key.ayah)"
            el.accessibilityHint = "Opens verse options and translation"
            el.accessibilityTraits = [.button]
            el.accessibilityFrameInContainerSpace = unionRect
            el.onActivate = { [weak self] in
                guard let self = self else { return }
                self.haptic.prepare()
                self.haptic.selectionChanged()
                self.onSelectAyah?(key)
            }
            el.accessibilityCustomActions = [
                UIAccessibilityCustomAction(name: "Show or hide reading controls") { [weak self] _ in
                    self?.onToggleChrome?()
                    return self != nil
                }
            ]
            elements.append(el)
        }

        self.accessibilityElements = elements
    }

    @objc private func handleHold(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let location = recognizer.location(in: self)
        let geo = currentGeometry()
        guard geo.displayedImageFrame.contains(location),
              let regions = content?.regions,
              let hit = geo.hitTest(containerPoint: location, regions: regions),
              let key = hit.verseKey else {
            return
        }
        haptic.prepare()
        haptic.selectionChanged()
        onSelectAyah?(key)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        onToggleChrome?()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === holdRecognizer {
            let loc = gestureRecognizer.location(in: self)
            let geo = currentGeometry()
            guard geo.displayedImageFrame.contains(loc), let regions = content?.regions else {
                return false
            }
            return geo.hitTest(containerPoint: loc, regions: regions) != nil
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === holdRecognizer {
            haptic.prepare()
        }
        return true
    }
}

@MainActor
private final class MushafFacsimileAccessibilityElement: UIAccessibilityElement {
    var verseKey: VerseKey?
    var onActivate: (() -> Void)?

    override func accessibilityActivate() -> Bool {
        onActivate?()
        return onActivate != nil
    }
}
#endif
