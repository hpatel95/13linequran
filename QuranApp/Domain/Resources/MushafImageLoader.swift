//
//  MushafImageLoader.swift
//  QuranApp
//
//  Off-main-actor ImageIO thumbnail decoding, bounded memory caching,
//  and neighbor prefetching for authentic Mushaf page scans.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import Foundation
import CoreGraphics
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

public actor MushafImageLoader: Sendable {
    public static let shared = MushafImageLoader()

    #if canImport(UIKit)
    private var cache = NSCache<NSString, UIImage>()
    #endif
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    public init(memoryCapacityMegabytes: Int = 48) {
        #if canImport(UIKit)
        self.cache.totalCostLimit = memoryCapacityMegabytes * 1024 * 1024
        self.cache.countLimit = 20
        #endif
    }

    #if canImport(UIKit)
    /// Loads and decodes an authentic page image off the main actor.
    /// If targetPixelSize is nil, decodes at native resolution.
    public func loadImage(
        for summary: MushafPageSummary,
        targetPixelSize: Int? = nil
    ) async -> UIImage? {
        guard let path = summary.imagePath else { return nil }
        let cacheKey = "\(summary.editionId):\(summary.id):\(targetPixelSize ?? 0)" as NSString

        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // Avoid duplicate concurrent decode tasks for the same page
        let key = cacheKey as String
        if let existing = inFlightTasks[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard let fileURL = resolveImageURL(for: path) else {
                return nil
            }
            return decodeImage(at: fileURL, maxPixelSize: targetPixelSize)
        }

        inFlightTasks[key] = task
        let image = await task.value
        inFlightTasks.removeValue(forKey: key)

        if let validImage = image {
            let cost = Int(validImage.size.width * validImage.size.height * 4)
            cache.setObject(validImage, forKey: cacheKey, cost: cost)
        }

        return image
    }

    /// Prefetches pages (e.g. current - 1, current + 1) in the background.
    public func prefetch(pages: [MushafPageSummary], targetPixelSize: Int? = nil) {
        for page in pages {
            Task {
                _ = await self.loadImage(for: page, targetPixelSize: targetPixelSize)
            }
        }
    }

    /// Clears the decoded image cache.
    public func clearCache() {
        cache.removeAllObjects()
    }

    // MARK: - Private Decoders
    private func decodeImage(at url: URL, maxPixelSize: Int?) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        var options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]

        if let maxSize = maxPixelSize, maxSize > 0 {
            options[kCGImageSourceCreateThumbnailFromImageAlways] = true
            options[kCGImageSourceThumbnailMaxPixelSize] = maxSize
            options[kCGImageSourceCreateThumbnailWithTransform] = true
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        } else {
            options[kCGImageSourceShouldCache] = true
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }
    }

    private func resolveImageURL(for relativePath: String) -> URL? {
        let cleanPath = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (cleanPath as NSString).lastPathComponent
        let nameWithoutExt = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        // 1. Check in Bundle.main by exact filename
        if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext) {
            return url
        }

        // 2. Check in Bundle.main with relative path
        if let url = Bundle.main.url(forResource: cleanPath, withExtension: nil) {
            return url
        }

        // 3. Check inside MushafEditions bundle subdirectory
        if let url = Bundle.main.url(forResource: nameWithoutExt, withExtension: ext, subdirectory: "MushafEditions") {
            return url
        }

        // 4. Fallback to development filesystem paths
        let candidatePaths = [
            "QuranApp/Resources/MushafEditions/\(cleanPath)",
            "QuranApp/Resources/MushafEditions/editions/taj-company-13-847/v1/pages/\(filename)",
            cleanPath
        ]

        for path in candidatePaths {
            let fileURL = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        return nil
    }
    #endif
}
