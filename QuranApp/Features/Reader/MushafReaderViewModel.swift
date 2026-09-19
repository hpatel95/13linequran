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
                scheduleLastReadAutoSave()
                Task { await checkCurrentPageBookmarked() }
            }
        }
    }
    
    public var selectedTranslationAuthor: Translation.TranslationAuthor = .saheeh
    public var isChromeVisible: Bool = true
    public var isTranslationSheetPresented: Bool = false
    public var isBookmarksSheetPresented: Bool = false
    public var isCurrentPageBookmarked: Bool = false
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
    public var juzs: [Juz] = []
    public var isLoading: Bool = false
    public var errorMessage: String?

    // MARK: - Dependencies
    public let repository: QuranRepositoryProtocol
    public let userDatabase: UserDatabaseServiceProtocol
    public let audioService: AudioPlayerService
    private var lastReadSaveTask: Task<Void, Never>?

    public init(
        repository: QuranRepositoryProtocol,
        userDatabase: UserDatabaseServiceProtocol,
        initialPage: Int = 1
    ) {
        self.repository = repository
        self.userDatabase = userDatabase
        self.currentPage = max(1, min(849, initialPage))
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
        if surahs.isEmpty {
            isLoading = true
            do {
                self.surahs = try await repository.fetchSurahs()
                self.juzs = (try? await repository.fetchJuzs()) ?? []
                await loadSurroundingPages()
                isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
        await refreshBookmarks()
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
            Task {
                try? await userDatabase.removeAyahBookmark(ayahId: ayahId)
            }
        } else {
            bookmarks.insert(ayahId)
            let ayah = selectedAyah
            let trans = activeAyahTranslation?.text ?? ""
            let sName = currentSurahName
            Task {
                if let a = ayah, a.id == ayahId {
                    let title = "\(sName) \(a.surahId):\(a.verseNumber)"
                    _ = try? await userDatabase.addAyahBookmark(
                        ayahId: a.id,
                        surahId: a.surahId,
                        verseNumber: a.verseNumber,
                        pageNumber: a.pageNumber,
                        title: title,
                        arabic: a.textClean,
                        translation: trans,
                        note: nil
                    )
                }
            }
        }
    }

    public func togglePageBookmark() {
        isCurrentPageBookmarked.toggle()
        let page = currentPage
        let isBookmarked = isCurrentPageBookmarked
        let sName = currentSurahName
        let jNum = currentJuzNumber

        Task {
            if isBookmarked {
                let title = "Page \(page) • \(sName) (Juz \(jNum))"
                _ = try? await userDatabase.addPageBookmark(pageNumber: page, title: title, note: nil)
            } else {
                try? await userDatabase.removePageBookmark(pageNumber: page)
            }
        }
    }

    public func refreshBookmarks() async {
        do {
            self.bookmarks = try await userDatabase.fetchBookmarkedAyahIds()
            self.isCurrentPageBookmarked = try await userDatabase.isPageBookmarked(pageNumber: currentPage)
        } catch {
            print("Error refreshing bookmarks: \(error)")
        }
    }

    private func checkCurrentPageBookmarked() async {
        self.isCurrentPageBookmarked = (try? await userDatabase.isPageBookmarked(pageNumber: currentPage)) ?? false
    }

    private func scheduleLastReadAutoSave() {
        lastReadSaveTask?.cancel()
        lastReadSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2.0-second dwell time
            guard !Task.isCancelled, let self = self else { return }
            try? await self.userDatabase.saveLastReadPage(self.currentPage)
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
    public func surahForPage(_ page: Int) -> Surah? {
        if let firstLine = pageLinesCache[page]?.first(where: { $0.surahId != nil }),
           let sId = firstLine.surahId,
           let surah = surahs.first(where: { $0.id == sId }) {
            return surah
        }
        return surahs.last(where: { $0.startPage <= page }) ?? surahs.first
    }

    public func juzForPage(_ page: Int) -> Juz? {
        if let j = juzs.last(where: { $0.startPage <= page }) {
            return j
        }
        return juzs.first
    }

    public var currentSurahName: String {
        surahForPage(currentPage)?.englishName ?? "Al-Fatihah"
    }

    public var currentSurahArabicName: String {
        surahForPage(currentPage)?.arabicName ?? ""
    }

    public var currentJuzNumber: Int {
        juzForPage(currentPage)?.id ?? 1
    }

    public var currentJuzArabicName: String {
        juzForPage(currentPage)?.nameArabic ?? ""
    }
}
