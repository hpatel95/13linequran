//
//  DownloadManager.swift
//  QuranApp
//
//  MainActor-isolated, @Observable background download manager handling
//  offline audio recitation packs (Sheikh Khalifa Al Tunaiji, 64kbps)
//  with bounded concurrency, integrity checks, and cache management.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class DownloadManager {
    public let repository: QuranRepositoryProtocol
    public var surahs: [Surah] = []
    public var downloadStatuses: [Int: DownloadStatus] = [:]
    public var totalStorageUsedBytes: Int64 = 0
    public var isLoading: Bool = false

    private var activeTasks: [Int: Task<Void, Never>] = [:]
    private let session: URLSession

    public init(repository: QuranRepositoryProtocol) {
        self.repository = repository

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Lifecycle & Scanning
    public func loadAndScan() async {
        isLoading = true
        do {
            if surahs.isEmpty {
                self.surahs = try await repository.fetchSurahs()
            }
            refreshStatuses()
            isLoading = false
        } catch {
            print("Failed to load surahs in DownloadManager: \(error)")
            isLoading = false
        }
    }

    public func refreshStatuses() {
        var totalBytes: Int64 = 0

        for surah in surahs {
            // If actively downloading, do not overwrite progress
            if let current = downloadStatuses[surah.id], current.isDownloading {
                continue
            }

            var downloadedCount = 0
            var surahBytes: Int64 = 0

            for verse in 1...surah.totalVerses {
                if AudioStorageLocator.fileExists(surahId: surah.id, verseNumber: verse) {
                    downloadedCount += 1
                    surahBytes += AudioStorageLocator.fileSize(surahId: surah.id, verseNumber: verse)
                }
            }

            totalBytes += surahBytes

            if downloadedCount == surah.totalVerses && surah.totalVerses > 0 {
                downloadStatuses[surah.id] = .downloaded
            } else if downloadedCount == 0 {
                downloadStatuses[surah.id] = .notDownloaded
            } else {
                // Partial download: show progress based on existing verses
                let progress = Double(downloadedCount) / Double(surah.totalVerses)
                downloadStatuses[surah.id] = .downloading(progress: progress)
            }
        }

        self.totalStorageUsedBytes = totalBytes
    }

    // MARK: - Download Operations
    public func downloadSurah(_ surah: Surah) {
        // Prevent re-downloading if already in progress
        if let status = downloadStatuses[surah.id], status.isDownloading {
            return
        }

        let surahId = surah.id
        let totalVerses = surah.totalVerses

        // Optimistically set status
        downloadStatuses[surahId] = .downloading(progress: 0.0)

        let task = Task { [weak self, session] in
            guard let self = self else { return }

            // Determine which verses still need downloading
            var neededVerses: [Int] = []
            var existingCount = 0
            for v in 1...totalVerses {
                if AudioStorageLocator.fileExists(surahId: surahId, verseNumber: v) {
                    existingCount += 1
                } else {
                    neededVerses.append(v)
                }
            }

            if neededVerses.isEmpty {
                await MainActor.run {
                    self.downloadStatuses[surahId] = .downloaded
                    self.refreshStatuses()
                }
                return
            }

            // Bounded concurrency pool: max 4 concurrent downloads
            let maxConcurrency = 4
            var completedCount = existingCount
            var nextIndex = 0
            let totalNeeded = neededVerses.count

            await withTaskGroup(of: (Int, Bool).self) { group in
                // Prime the initial batch
                while nextIndex < min(maxConcurrency, totalNeeded) {
                    let verse = neededVerses[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        let success = await self.downloadSingleVerse(session: session, surahId: surahId, verseNumber: verse)
                        return (verse, success)
                    }
                }

                // Drain and refill concurrently
                for await (_, success) in group {
                    if Task.isCancelled { break }

                    if success {
                        completedCount += 1
                    }

                    let progress = Double(completedCount) / Double(totalVerses)
                    await MainActor.run {
                        self.downloadStatuses[surahId] = .downloading(progress: progress)
                    }

                    if nextIndex < totalNeeded {
                        let nextVerse = neededVerses[nextIndex]
                        nextIndex += 1
                        group.addTask {
                            let nextSuccess = await self.downloadSingleVerse(session: session, surahId: surahId, verseNumber: nextVerse)
                            return (nextVerse, nextSuccess)
                        }
                    }
                }
            }

            guard !Task.isCancelled else { return }

            // Final integrity check
            var allSucceeded = true
            for v in 1...totalVerses {
                if !AudioStorageLocator.fileExists(surahId: surahId, verseNumber: v) {
                    allSucceeded = false
                    break
                }
            }

            await MainActor.run {
                if allSucceeded {
                    self.downloadStatuses[surahId] = .downloaded
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                } else {
                    self.downloadStatuses[surahId] = .failed("Some verses failed to download. Tap to retry.")
                }
                self.activeTasks[surahId] = nil
                self.refreshStatuses()
            }
        }

        activeTasks[surahId] = task
    }

    private func downloadSingleVerse(session: URLSession, surahId: Int, verseNumber: Int) async -> Bool {
        let remoteURL = AudioStorageLocator.remoteFileURL(surahId: surahId, verseNumber: verseNumber)
        let localURL = AudioStorageLocator.localFileURL(surahId: surahId, verseNumber: verseNumber)

        do {
            let (tempURL, response) = try await session.download(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }

            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: localURL.path) {
                try? fileManager.removeItem(at: localURL)
            }

            try fileManager.moveItem(at: tempURL, to: localURL)
            AudioStorageLocator.excludeFromBackup(url: localURL)
            return true
        } catch {
            return false
        }
    }

    public func cancelDownload(surahId: Int) {
        activeTasks[surahId]?.cancel()
        activeTasks[surahId] = nil
        refreshStatuses()
    }

    public func deleteSurahDownload(_ surah: Surah) {
        cancelDownload(surahId: surah.id)

        let fileManager = FileManager.default
        for v in 1...surah.totalVerses {
            let fileURL = AudioStorageLocator.localFileURL(surahId: surah.id, verseNumber: v)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        downloadStatuses[surah.id] = .notDownloaded
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        refreshStatuses()
    }

    public func clearAllAudioCache() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()

        let fileManager = FileManager.default
        let dir = AudioStorageLocator.downloadsDirectory
        if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for file in contents {
                try? fileManager.removeItem(at: file)
            }
        }

        for surah in surahs {
            downloadStatuses[surah.id] = .notDownloaded
        }
        totalStorageUsedBytes = 0

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    // MARK: - Helpers
    public var downloadedSurahsCount: Int {
        downloadStatuses.values.filter { $0.isDownloaded }.count
    }

    public func formattedStorageSize() -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useMB, .useGB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: totalStorageUsedBytes)
    }

    public func status(for surahId: Int) -> DownloadStatus {
        downloadStatuses[surahId] ?? .notDownloaded
    }
}
