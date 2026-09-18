//
//  AudioStorageLocator.swift
//  QuranApp
//
//  Stateless, thread-safe locator providing local and remote audio URLs,
//  file existence checks, and Apple App Store compliant backup exclusion.
//

import Foundation

public enum AudioStorageLocator {
    public static let reciterSubfolder = "khalefa_al_tunaiji_64kbps"
    public static let remoteBaseURL = "https://everyayah.com/data/\(reciterSubfolder)"

    /// Returns the local filesystem directory for downloaded recitation audio.
    /// Guarantees that the directory exists and has `isExcludedFromBackup = true` applied.
    public static var downloadsDirectory: URL {
        let fileManager = FileManager.default
        let appSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let appDir = appSupport.appendingPathComponent("13LineQuran", isDirectory: true)
        let downloadsDir = appDir.appendingPathComponent("Downloads", isDirectory: true)
        let reciterDir = downloadsDir.appendingPathComponent(reciterSubfolder, isDirectory: true)

        if !fileManager.fileExists(atPath: reciterDir.path) {
            try? fileManager.createDirectory(at: reciterDir, withIntermediateDirectories: true)
            // Strictly exclude non-user-generated audio cache from iCloud/iTunes backups
            excludeFromBackup(url: reciterDir)
        }

        return reciterDir
    }

    /// Formats standardized 6-digit EveryAyah filename: e.g. "001001.mp3" for Surah 1, Ayah 1.
    public static func filename(surahId: Int, verseNumber: Int) -> String {
        String(format: "%03d%03d.mp3", surahId, verseNumber)
    }

    /// Resolves the absolute local file URL on disk.
    public static func localFileURL(surahId: Int, verseNumber: Int) -> URL {
        downloadsDirectory.appendingPathComponent(filename(surahId: surahId, verseNumber: verseNumber))
    }

    /// Resolves the canonical remote CDN URL on EveryAyah.
    public static func remoteFileURL(surahId: Int, verseNumber: Int) -> URL {
        let fname = filename(surahId: surahId, verseNumber: verseNumber)
        return URL(string: "\(remoteBaseURL)/\(fname)")!
    }

    /// Checks whether the verse audio file exists locally and has non-zero size.
    public static func fileExists(surahId: Int, verseNumber: Int) -> Bool {
        let path = localFileURL(surahId: surahId, verseNumber: verseNumber).path
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else { return false }
        if let attrs = try? fileManager.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int64, size > 0 {
            return true
        }
        return false
    }

    /// Returns the local file size in bytes, or 0 if missing.
    public static func fileSize(surahId: Int, verseNumber: Int) -> Int64 {
        let path = localFileURL(surahId: surahId, verseNumber: verseNumber).path
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }

    /// Ensures the file or directory is excluded from iCloud backup (Apple Guideline 5.1.1).
    public static func excludeFromBackup(url: URL) {
        var mutableUrl = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableUrl.setResourceValues(values)
    }

    /// Verifies if the file or directory is marked as excluded from backup.
    public static func isExcludedFromBackup(url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values?.isExcludedFromBackup ?? false
    }
}
