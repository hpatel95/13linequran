//
//  DownloadManagerTests.swift
//  QuranAppTests
//
//  Unit tests verifying AudioStorageLocator URL resolutions,
//  iCloud backup exclusion compliance, file size tracking, and DownloadStatus transitions.
//

import XCTest
@testable import QuranApp

final class DownloadManagerTests: XCTestCase {

    func testFilenameFormatting() {
        XCTAssertEqual(AudioStorageLocator.filename(surahId: 1, verseNumber: 1), "001001.mp3")
        XCTAssertEqual(AudioStorageLocator.filename(surahId: 2, verseNumber: 255), "002255.mp3")
        XCTAssertEqual(AudioStorageLocator.filename(surahId: 114, verseNumber: 6), "114006.mp3")
        XCTAssertEqual(AudioStorageLocator.filename(surahId: 36, verseNumber: 83), "036083.mp3")
    }

    func testURLResolution() {
        let remote = AudioStorageLocator.remoteFileURL(surahId: 1, verseNumber: 1)
        XCTAssertEqual(
            remote.absoluteString,
            "https://everyayah.com/data/khalefa_al_tunaiji_64kbps/001001.mp3",
            "Remote URL must point to Sheikh Khalifa Al Tunaiji 64kbps CDN on EveryAyah."
        )

        let local = AudioStorageLocator.localFileURL(surahId: 1, verseNumber: 1)
        XCTAssertTrue(local.isFileURL)
        XCTAssertTrue(local.path.contains("khalefa_al_tunaiji_64kbps"))
        XCTAssertTrue(local.path.hasSuffix("001001.mp3"))
    }

    func testDownloadsDirectoryAndBackupExclusion() {
        let dir = AudioStorageLocator.downloadsDirectory
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)

        XCTAssertTrue(exists, "Downloads directory must be created on access.")
        XCTAssertTrue(isDir.boolValue, "Path must point to a directory.")

        // Verify Apple App Store Guideline 5.1.1 (Non-user generated audio cache excluded from iCloud backup)
        let isExcluded = AudioStorageLocator.isExcludedFromBackup(url: dir)
        XCTAssertTrue(isExcluded, "Audio cache directory MUST be excluded from iCloud backup.")
    }

    func testStatusTransitions() {
        let notDownloaded = DownloadStatus.notDownloaded
        XCTAssertFalse(notDownloaded.isDownloaded)
        XCTAssertFalse(notDownloaded.isDownloading)
        XCTAssertEqual(notDownloaded.progressValue, 0.0)

        let downloading = DownloadStatus.downloading(progress: 0.65)
        XCTAssertFalse(downloading.isDownloaded)
        XCTAssertTrue(downloading.isDownloading)
        XCTAssertEqual(downloading.progressValue, 0.65, accuracy: 0.001)

        let downloaded = DownloadStatus.downloaded
        XCTAssertTrue(downloaded.isDownloaded)
        XCTAssertFalse(downloaded.isDownloading)
        XCTAssertEqual(downloaded.progressValue, 1.0)

        let failed = DownloadStatus.failed("Network error")
        XCTAssertFalse(failed.isDownloaded)
        XCTAssertFalse(failed.isDownloading)
        XCTAssertEqual(failed.progressValue, 0.0)
    }

    func testFileExistenceAndSizeTracking() throws {
        let testSurahId = 999
        let testVerseNumber = 999
        let testURL = AudioStorageLocator.localFileURL(surahId: testSurahId, verseNumber: testVerseNumber)

        // Ensure clean initial state
        if FileManager.default.fileExists(atPath: testURL.path) {
            try FileManager.default.removeItem(at: testURL)
        }
        XCTAssertFalse(AudioStorageLocator.fileExists(surahId: testSurahId, verseNumber: testVerseNumber))
        XCTAssertEqual(AudioStorageLocator.fileSize(surahId: testSurahId, verseNumber: testVerseNumber), 0)

        // Write mock audio payload
        let mockData = Data(repeating: 0xAA, count: 4096)
        try mockData.write(to: testURL)

        XCTAssertTrue(AudioStorageLocator.fileExists(surahId: testSurahId, verseNumber: testVerseNumber))
        XCTAssertEqual(AudioStorageLocator.fileSize(surahId: testSurahId, verseNumber: testVerseNumber), 4096)

        // Clean up
        try FileManager.default.removeItem(at: testURL)
        XCTAssertFalse(AudioStorageLocator.fileExists(surahId: testSurahId, verseNumber: testVerseNumber))
    }
}
