//
//  DownloadModels.swift
//  QuranApp
//
//  Thread-safe models and state enumerations representing offline recitation downloads.
//

import Foundation

public enum DownloadStatus: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)  // 0.0 ... 1.0
    case downloaded
    case failed(String)

    public var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    public var isDownloaded: Bool {
        self == .downloaded
    }

    public var progressValue: Double {
        if case .downloading(let p) = self { return p }
        if self == .downloaded { return 1.0 }
        return 0.0
    }
}

public struct SurahDownloadItem: Identifiable, Sendable {
    public var id: Int { surah.id }
    public let surah: Surah
    public var status: DownloadStatus
    public var localSizeBytes: Int64

    public init(
        surah: Surah,
        status: DownloadStatus = .notDownloaded,
        localSizeBytes: Int64 = 0
    ) {
        self.surah = surah
        self.status = status
        self.localSizeBytes = localSizeBytes
    }
}
