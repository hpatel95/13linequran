//
//  MushafImageGeometryTests.swift
//  QuranAppTests
//
//  Unit tests verifying mathematical aspect-fit transformations,
//  letterboxing offsets, touch rejection, and hit-testing specificity.
//

import XCTest
import CoreGraphics
@testable import QuranApp

final class MushafImageGeometryTests: XCTestCase {

    func testAspectFitScaleAndOffsetsPillarboxed() {
        // Container is wider than image aspect ratio (Pillarbox)
        // Image: 720 x 1057 (ratio ~ 0.681)
        // Container: 1000 x 1057
        let container = CGSize(width: 1000, height: 1057)
        let image = CGSize(width: 720, height: 1057)

        let geo = MushafImageGeometry(containerSize: container, imageSize: image)

        XCTAssertEqual(geo.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(geo.offsetY, 0.0, accuracy: 0.001)
        XCTAssertEqual(geo.offsetX, 140.0, accuracy: 0.001) // (1000 - 720) / 2 = 140

        let frame = geo.displayedImageFrame
        XCTAssertEqual(frame.origin.x, 140.0, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(frame.width, 720.0, accuracy: 0.001)
        XCTAssertEqual(frame.height, 1057.0, accuracy: 0.001)
    }

    func testAspectFitScaleAndOffsetsLetterboxed() {
        // Container is taller than image aspect ratio (Letterbox)
        // Image: 720 x 1000
        // Container: 720 x 1500
        let container = CGSize(width: 720, height: 1500)
        let image = CGSize(width: 720, height: 1000)

        let geo = MushafImageGeometry(containerSize: container, imageSize: image)

        XCTAssertEqual(geo.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(geo.offsetX, 0.0, accuracy: 0.001)
        XCTAssertEqual(geo.offsetY, 250.0, accuracy: 0.001) // (1500 - 1000) / 2 = 250
    }

    func testNormalizedPointConversionWithinImage() {
        let container = CGSize(width: 1000, height: 1000)
        let image = CGSize(width: 500, height: 500)

        // Scale = 1.0 (min(2.0, 2.0)? No, min(1000/500, 1000/500) = 2.0)
        // Image displayed at 1000 x 1000, offsets (0, 0)
        let geo = MushafImageGeometry(containerSize: container, imageSize: image)
        XCTAssertEqual(geo.scale, 2.0, accuracy: 0.001)

        let touch = CGPoint(x: 500, y: 500)
        let normalized = geo.normalizedPoint(from: touch)

        XCTAssertNotNil(normalized)
        XCTAssertEqual(normalized!.u, 0.5, accuracy: 0.001)
        XCTAssertEqual(normalized!.v, 0.5, accuracy: 0.001)
    }

    func testTouchRejectionOutsideImageLetterbox() {
        let container = CGSize(width: 1000, height: 1000)
        let image = CGSize(width: 500, height: 1000)
        // Scale = min(2.0, 1.0) = 1.0
        // Displayed width = 500, height = 1000, offsetX = (1000 - 500) / 2 = 250
        let geo = MushafImageGeometry(containerSize: container, imageSize: image)

        // Touch in the left letterbox area (x = 100 < 250)
        let touchLeft = CGPoint(x: 100, y: 500)
        XCTAssertNil(geo.normalizedPoint(from: touchLeft), "Touches in letterbox must be rejected")

        // Touch in the right letterbox area (x = 800 > 750)
        let touchRight = CGPoint(x: 800, y: 500)
        XCTAssertNil(geo.normalizedPoint(from: touchRight), "Touches in letterbox must be rejected")
    }

    func testViewRectConversion() {
        let container = CGSize(width: 1000, height: 1000)
        let image = CGSize(width: 1000, height: 1000)
        let geo = MushafImageGeometry(containerSize: container, imageSize: image)

        guard let rect = NormalizedRect(minX: 0.1, minY: 0.2, maxX: 0.6, maxY: 0.8) else {
            XCTFail("Failed to create NormalizedRect")
            return
        }

        let viewRect = geo.viewRect(for: rect)
        XCTAssertEqual(viewRect.origin.x, 100.0, accuracy: 0.001)
        XCTAssertEqual(viewRect.origin.y, 200.0, accuracy: 0.001)
        XCTAssertEqual(viewRect.width, 500.0, accuracy: 0.001)
        XCTAssertEqual(viewRect.height, 600.0, accuracy: 0.001)
    }

    func testHitTestingSpecificitySmallestArea() {
        let container = CGSize(width: 1000, height: 1000)
        let image = CGSize(width: 1000, height: 1000)
        let geo = MushafImageGeometry(containerSize: container, imageSize: image)

        // Larger enclosing region (e.g. paragraph or wide verse)
        let largeRect = NormalizedRect(validatedMinX: 0.1, minY: 0.1, maxX: 0.9, maxY: 0.9)
        let largeRegion = MushafRegion(
            id: "large",
            pageId: "p0001",
            kind: .ayah,
            verseKey: VerseKey(validatedSurah: 1, ayah: 1),
            fragmentOrder: 1,
            sourceOrder: 1,
            label: "1:1",
            rect: largeRect
        )

        // Smaller specific region overlapping at (0.5, 0.5)
        let smallRect = NormalizedRect(validatedMinX: 0.4, minY: 0.4, maxX: 0.6, maxY: 0.6)
        let smallRegion = MushafRegion(
            id: "small",
            pageId: "p0001",
            kind: .ayah,
            verseKey: VerseKey(validatedSurah: 1, ayah: 2),
            fragmentOrder: 1,
            sourceOrder: 2,
            label: "1:2",
            rect: smallRect
        )

        let hit = geo.hitTest(containerPoint: CGPoint(x: 500, y: 500), regions: [largeRegion, smallRegion])
        XCTAssertNotNil(hit)
        XCTAssertEqual(hit?.id, "small", "Hit testing must prioritize smaller, more specific bounding boxes")
    }
}
