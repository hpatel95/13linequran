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
                dismissAyahSelection()
                pageLoadTask?.cancel()
                pageLoadTask = Task { [weak self] in
                    guard let self else { return }
                    await self.loadSurroundingPages()
                }
                scheduleLastReadAutoSave()
                Task { await checkCurrentPageBookmarked() }
            }
        }
    }
    
    public var selectedTranslationAuthor: Translation.TranslationAuthor = .saheeh {
        didSet {
            if oldValue != selectedTranslationAuthor { loadSelectedTranslation() }
        }
    }
    public var isChromeVisible: Bool = true
    public var isTranslationSheetPresented: Bool = false {
        didSet {
            // Dismissing the sheet keeps the golden glaze so the reader can still
            // see which verse was inspected; the selection is cleared when the page
            // changes or another Ayah is chosen.
            if oldValue && !isTranslationSheetPresented {
                translationTask?.cancel()
                translationGeneration += 1
            }
        }
    }
    public var isBookmarksSheetPresented: Bool = false
    public var isCurrentPageBookmarked: Bool = false
    public private(set) var activeAyahTranslation: Translation?
    public private(set) var selectedAyah: Ayah?
    /// Available synchronously on recognition, before either database request.
    public private(set) var selectedVerseKey: String?
    public var bookmarks: Set<Int> = []

    // Windowed Cache: [PageNumber: [MushafLine]]
    public var pageLinesCache: [Int: [MushafLine]] = [:]
    public var surahs: [Surah] = []
    public private(set) var surahsByID: [Int: Surah] = [:]
    public var juzs: [Juz] = []
    public var isLoading: Bool = false
    public var errorMessage: String?

    // MARK: - Dependencies
    public let repository: QuranRepositoryProtocol
    public let userDatabase: UserDatabaseServiceProtocol
    public let audioService: AudioPlayerService
    @ObservationIgnored private var lastReadSaveTask: Task<Void, Never>?
    @ObservationIgnored private var pageLoadTask: Task<Void, Never>?
    @ObservationIgnored private var selectionTask: Task<Void, Never>?
    @ObservationIgnored private var translationTask: Task<Void, Never>?
    @ObservationIgnored private var pageGeneration = 0
    @ObservationIgnored private var selectionGeneration = 0
    @ObservationIgnored private var translationGeneration = 0

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
                // Do not replace a verse the user is currently inspecting.
                guard selectionTask == nil, !isTranslationSheetPresented else { return }
                if ayah.pageNumber != currentPage {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                        self.currentPage = ayah.pageNumber
                    }
                }
                self.selectedAyah = ayah
                self.selectedVerseKey = ayah.verseKey
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
                self.surahsByID = Dictionary(uniqueKeysWithValues: surahs.map { ($0.id, $0) })
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

    public func toggleChrome(reduceMotion: Bool = false) {
        if reduceMotion {
            isChromeVisible.toggle()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                isChromeVisible.toggle()
            }
        }
    }

    public func jumpToPage(_ page: Int) {
        let clamped = max(1, min(849, page))
        self.currentPage = clamped
    }

    public func jumpToSurah(_ surah: Surah) {
        self.jumpToPage(surah.startPage)
    }

    public func beginSelectingAyah(surahId: Int, verseNumber: Int) {
        selectionTask?.cancel()
        translationTask?.cancel()
        selectionGeneration += 1
        translationGeneration += 1
        let generation = selectionGeneration
        let key = "\(surahId):\(verseNumber)"
        selectedVerseKey = key
        selectedAyah = nil
        activeAyahTranslation = nil
        errorMessage = nil

        selectionTask = Task { [weak self, repository] in
            do {
                let ayah = try await repository.fetchAyah(surah: surahId, verse: verseNumber)
                guard let self, !Task.isCancelled, self.selectionGeneration == generation else { return }
                guard let ayah, ayah.verseKey == key else {
                    self.dismissAyahSelection()
                    self.errorMessage = "The selected verse could not be loaded."
                    return
                }
                self.selectedAyah = ayah
                self.selectionTask = nil
                self.isTranslationSheetPresented = true
                self.loadSelectedTranslation()
                // Ayah.pageNumber is its first fragment, not necessarily the
                // touched page. Opening a continuation must never jump backwards.
            } catch {
                guard let self, !Task.isCancelled, self.selectionGeneration == generation else { return }
                self.dismissAyahSelection()
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Async convenience for index/bookmark callers; gesture callers use the
    /// synchronous entry point so the gold glaze does not wait for a task hop.
    public func selectAyah(surahId: Int, verseNumber: Int) async {
        beginSelectingAyah(surahId: surahId, verseNumber: verseNumber)
        let pending = selectionTask
        await pending?.value
    }

    public func dismissAyahSelection() {
        if isTranslationSheetPresented {
            // Setting false cancels the pending translation request.
            isTranslationSheetPresented = false
        }
        clearSelectionState()
    }

    private func clearSelectionState() {
        selectionGeneration += 1
        translationGeneration += 1
        selectionTask?.cancel()
        translationTask?.cancel()
        selectionTask = nil
        translationTask = nil
        selectedVerseKey = nil
        selectedAyah = nil
        activeAyahTranslation = nil
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
            let page = currentPage
            let bookmarked = try await userDatabase.isPageBookmarked(pageNumber: page)
            if currentPage == page { self.isCurrentPageBookmarked = bookmarked }
        } catch {
            print("Error refreshing bookmarks: \(error)")
        }
    }

    private func checkCurrentPageBookmarked() async {
        let page = currentPage
        let bookmarked = (try? await userDatabase.isPageBookmarked(pageNumber: page)) ?? false
        if currentPage == page { self.isCurrentPageBookmarked = bookmarked }
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
        selectedTranslationAuthor = author
        let pending = translationTask
        await pending?.value
    }

    private func loadSelectedTranslation() {
        translationTask?.cancel()
        translationGeneration += 1
        activeAyahTranslation = nil
        guard let ayah = selectedAyah else { return }
        let generation = translationGeneration
        let author = selectedTranslationAuthor
        translationTask = Task { [weak self, repository] in
            do {
                let translation = try await repository.fetchTranslation(ayahId: ayah.id, authorCode: author)
                guard let self, !Task.isCancelled, self.translationGeneration == generation,
                      self.selectedAyah?.id == ayah.id, self.selectedTranslationAuthor == author else { return }
                self.activeAyahTranslation = translation
            } catch {
                guard let self, !Task.isCancelled, self.translationGeneration == generation else { return }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Windowed Page Loading (N-1, N, N+1)
    private func loadSurroundingPages() async {
        pageGeneration += 1
        let generation = pageGeneration
        let center = currentPage
        let targets = [center, center - 1, center + 1].filter { (1...849).contains($0) }
        let keepSet = Set(targets)
        pageLinesCache = pageLinesCache.filter { keepSet.contains($0.key) }

        await withTaskGroup(of: (Int, [MushafLine]?).self) { group in
            for page in targets where pageLinesCache[page] == nil {
                group.addTask { [repository] in
                    let lines = try? await repository.fetchLines(forPage: page)
                    return (page, lines)
                }
            }
            for await (page, lines) in group {
                guard !Task.isCancelled, generation == pageGeneration, center == currentPage else {
                    group.cancelAll()
                    continue
                }
                if let lines {
                    pageLinesCache[page] = lines
                } else if page == center {
                    errorMessage = "Page \(page) could not be loaded from the bundled Quran."
                }
            }
        }
    }

    // MARK: - Helpers
    public func surahForPage(_ page: Int) -> Surah? {
        if let firstLine = pageLinesCache[page]?.first(where: { $0.surahId != nil }),
           let sId = firstLine.surahId,
           let surah = surahsByID[sId] {
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
