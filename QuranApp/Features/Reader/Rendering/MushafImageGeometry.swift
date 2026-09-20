//
//  MushafImageGeometry.swift
//  QuranApp
//
//  Aspect-fit transform mathematics, letterbox offset compensation,
//  and hit-testing for authentic Mushaf scanned page coordinates.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation
import CoreGraphics

public struct MushafImageGeometry: Sendable {
    public let containerSize: CGSize
    public let imageSize: CGSize
    public let scale: CGFloat
    public let offsetX: CGFloat
    public let offsetY: CGFloat

    public init(containerSize: CGSize, imageSize: CGSize) {
        self.containerSize = containerSize
        self.imageSize = imageSize

        guard containerSize.width > 0, containerSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            self.scale = 1.0
            self.offsetX = 0
            self.offsetY = 0
            return
        }

        let scaleX = containerSize.width / imageSize.width
        let scaleY = containerSize.height / imageSize.height
        let fitScale = min(scaleX, scaleY)
        self.scale = fitScale

        let displayedWidth = imageSize.width * fitScale
        let displayedHeight = imageSize.height * fitScale
        self.offsetX = (containerSize.width - displayedWidth) / 2.0
        self.offsetY = (containerSize.height - displayedHeight) / 2.0
    }

    /// The bounding rectangle of the rendered image within the container view.
    public var displayedImageFrame: CGRect {
        CGRect(
            x: offsetX,
            y: offsetY,
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    /// Converts a container touch point into normalized image coordinates [0, 1].
    /// Returns `nil` if the touch falls outside the displayed image (letterbox/pillarbox area).
    public func normalizedPoint(from containerPoint: CGPoint) -> (u: Double, v: Double)? {
        let frame = displayedImageFrame
        guard frame.contains(containerPoint), frame.width > 0, frame.height > 0 else {
            return nil
        }

        let u = Double((containerPoint.x - frame.minX) / frame.width)
        let v = Double((containerPoint.y - frame.minY) / frame.height)
        let clampedU = max(0.0, min(1.0, u))
        let clampedV = max(0.0, min(1.0, v))
        return (clampedU, clampedV)
    }

    /// Converts a normalized rectangle [0, 1] into a container view coordinate CGRect.
    public func viewRect(for normalized: NormalizedRect) -> CGRect {
        let frame = displayedImageFrame
        return CGRect(
            x: frame.minX + CGFloat(normalized.minX) * frame.width,
            y: frame.minY + CGFloat(normalized.minY) * frame.height,
            width: CGFloat(normalized.width) * frame.width,
            height: CGFloat(normalized.height) * frame.height
        )
    }

    /// Hit-tests a container touch point against a set of interactive regions on the page.
    /// Selects the region containing the normalized point, prioritizing smaller bounding boxes (higher specificity).
    public func hitTest(
        containerPoint: CGPoint,
        regions: [MushafRegion]
    ) -> MushafRegion? {
        guard let (u, v) = normalizedPoint(from: containerPoint) else {
            return nil
        }

        var candidate: MushafRegion?
        var smallestArea = Double.greatestFiniteMagnitude

        for region in regions {
            if region.rect.contains(u: u, v: v) {
                if region.rect.area < smallestArea {
                    candidate = region
                    smallestArea = region.rect.area
                }
            }
        }

        return candidate
    }
}
