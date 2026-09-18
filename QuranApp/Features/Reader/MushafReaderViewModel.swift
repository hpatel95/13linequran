//
//  MushafReaderViewModel.swift
//  QuranApp
//
//  Main actor-isolated, @Observable state manager for the 13-line Mushaf reader.
//  Implements windowed page caching (N-1, N, N+1) and smooth navigation.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class MushafReaderViewModel {
    // MARK: - State
    public var currentPage: Int = 1 {
        didSet {
            if currentPage != oldValue {
                Task { await loadSurroundingPages() }
            }
        }
    }
    
    public var selectedTranslationAuthor: Translation.TranslationAuthor = .saheeh
    public var isChromeVisible: Bool = true
    public var isTranslationSheetPresented: Bool = false
    public var activeAyahTranslation: Translation?
    public var selectedAyah: Ayah?
    public var bookmarks: Set<Int> = []

    public var selectedVerseKey: String? {
        guard let ayah = selectedAyah else { return nil }
        return "\(ayah.surahId):\(ayah.verseNumber)"
    }

    // Windowed Cache: [PageNumber: [MushafLine]]
    public var pageLinesCache: [Int: [MushafLine]] = [:]
    public var surahs: [Surah] = []
    public var isLoading: Bool = false
    public var errorMessage: String?

    // MARK: - Dependencies
    public let repository: QuranRepositoryProtocol
    public let audioService: AudioPlayerService

    public init(repository: QuranRepositoryProtocol) {
        self.repository = repository
        self.audioService = AudioPlayerService(repository: repository)
        setupAudioSync()
    }

    private func setupAudioSync() {
        audioService.onVerseChanged = { [weak self] surahId, verseNumber in
            Task { @MainActor in
                await self?.handleAudioVerseChanged(surahId: surahId, verseNumber: verseNumber)
            }
        }
    }

    private func handleAudioVerseChanged(surahId: Int, verseNumber: Int) async {
        do {
            if let ayah = try await repository.fetchAyah(surah: surahId, verse: verseNumber) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                    self.selectedAyah = ayah
                }
                // Auto-advance page if recitation crossed page boundary
                if ayah.pageNumber != currentPage {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                        self.currentPage = ayah.pageNumber
                    }
                }
            }
        } catch {
            print("Failed to sync verse with audio: \(error)")
        }
    }

    // MARK: - Actions
    public func onAppear() async {
        guard surahs.isEmpty else { return }
        isLoading = true
        do {
            self.surahs = try await repository.fetchSurahs()
            await loadSurroundingPages()
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    public func toggleChrome() {
        withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
            isChromeVisible.toggle()
        }
    }

    public func jumpToPage(_ page: Int) {
        let clamped = max(1, min(849, page))
        self.currentPage = clamped
    }

    public func jumpToSurah(_ surah: Surah) {
        self.jumpToPage(surah.startPage)
    }

    public func selectAyah(surahId: Int, verseNumber: Int) async {
        do {
            if let ayah = try await repository.fetchAyah(surah: surahId, verse: verseNumber) {
                self.selectedAyah = ayah
                self.activeAyahTranslation = try await repository.fetchTranslation(
                    ayahId: ayah.id,
                    authorCode: selectedTranslationAuthor
                )
                self.isTranslationSheetPresented = true
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    public func toggleBookmark(ayahId: Int) {
        if bookmarks.contains(ayahId) {
            bookmarks.remove(ayahId)
        } else {
            bookmarks.insert(ayahId)
        }
    }

    public func changeTranslationAuthor(_ author: Translation.TranslationAuthor) async {
        self.selectedTranslationAuthor = author
        if let ayah = selectedAyah {
            self.activeAyahTranslation = try? await repository.fetchTranslation(
                ayahId: ayah.id,
                authorCode: author
            )
        }
    }

    // MARK: - Windowed Page Loading (N-1, N, N+1)
    private func loadSurroundingPages() async {
        let targets = [currentPage - 1, currentPage, currentPage + 1].filter { $0 >= 1 && $0 <= 849 }

        // Prune distant cached pages to conserve memory
        let keepSet = Set(targets)
        pageLinesCache = pageLinesCache.filter { keepSet.contains($0.key) }

        // Fetch missing pages concurrently
        await withTaskGroup(of: (Int, [MushafLine]?).self) { group in
            for page in targets where pageLinesCache[page] == nil {
                group.addTask { [repository] in
                    let lines = try? await repository.fetchLines(forPage: page)
                    return (page, lines)
                }
            }

            for await (page, lines) in group {
                if let lines = lines {
                    pageLinesCache[page] = lines
                }
            }
        }
    }

    // MARK: - Helpers
    public var currentSurahName: String {
        guard let firstLine = pageLinesCache[currentPage]?.first(where: { $0.surahId != nil }),
              let sId = firstLine.surahId,
              let surah = surahs.first(where: { $0.id == sId }) else {
            // Fallback finding surah containing current page
            return surahs.last(where: { $0.startPage <= currentPage })?.englishName ?? "Al-Fatihah"
        }
        return surah.englishName
    }

    public var currentJuzNumber: Int {
        // Approximate or lookup from metadata
        surahs.last(where: { $0.startPage <= currentPage })?.juzNumber ?? 1
    }
}
