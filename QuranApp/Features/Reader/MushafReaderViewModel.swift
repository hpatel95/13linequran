//
//  MushafReaderViewModel.swift
//  QuranApp
//
//  Main actor-isolated, @Observable state manager for the authentic 13-line Mushaf reader.
//  Coordinates authentic facsimile pages, accessible text fallback, windowed image prefetching,
//  audio recitation follow, and user bookmark persistence.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class MushafReaderViewModel {
    // MARK: - Display Mode
    public enum ReaderDisplayMode: String, CaseIterable, Sendable {
        case authenticFacsimile = "Authentic Scan"
        case accessibleText = "Accessible Text"
    }

    // MARK: - Active State
    public var activeEditionId: String = "taj-company-13-847"
    public var displayMode: ReaderDisplayMode = .authenticFacsimile

    /// 1-based navigation index in the active edition (e.g. 1 ... 848).
    public var currentPageIndex: Int = 1 {
        didSet {
            if currentPageIndex != oldValue {
                onPageIndexChanged(from: oldValue, to: currentPageIndex)
            }
        }
    }

    /// Backward compatibility property: resolves to the 1-based Quran page number (1...847),
    /// or navigation index if ordinal is unavailable.
    public var currentPage: Int {
        get {
            currentPageSummary?.quranOrdinal ?? currentPageIndex
        }
        set {
            jumpToQuranOrdinal(newValue)
        }
    }

    public var pages: [MushafPageSummary] = []
    public var pageContentCache: [String: MushafPageContent] = [:]
    public var pageAyahsCache: [Int: [Ayah]] = [:]
    public var pageLinesCache: [Int: [MushafLine]] = [:]

    public var selectedTranslationAuthor: Translation.TranslationAuthor = .saheeh {
        didSet {
            if oldValue != selectedTranslationAuthor { loadSelectedTranslation() }
        }
    }

    public var isChromeVisible: Bool = true
    public var isTranslationSheetPresented: Bool = false {
        didSet {
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
    public private(set) var selectedVerseKey: String?
    public private(set) var selectedVerseKeyObj: VerseKey?
    public private(set) var playingVerseKeyObj: VerseKey?
    public var bookmarks: Set<Int> = []

    public var surahs: [Surah] = []
    public private(set) var surahsByID: [Int: Surah] = [:]
    public var juzs: [Juz] = []
    public var isLoading: Bool = false
    public var errorMessage: String?

    // MARK: - Dependencies
    public let repository: QuranRepositoryProtocol
    public let userDatabase: UserDatabaseServiceProtocol
    public let editionRepository: any MushafEditionRepositoryProtocol
    public let audioService: AudioPlayerService

    @ObservationIgnored private var lastReadSaveTask: Task<Void, Never>?
    @ObservationIgnored private var pageLoadTask: Task<Void, Never>?
    @ObservationIgnored private var selectionTask: Task<Void, Never>?
    @ObservationIgnored private var translationTask: Task<Void, Never>?
    @ObservationIgnored private var pageGeneration = 0
    @ObservationIgnored private var selectionGeneration = 0
    @ObservationIgnored private var translationGeneration = 0
    private let locationResolver: ReaderLocationResolver

    public init(
        repository: QuranRepositoryProtocol,
        userDatabase: UserDatabaseServiceProtocol,
        editionRepository: (any MushafEditionRepositoryProtocol)? = nil,
        initialPage: Int = 1
    ) {
        self.repository = repository
        self.userDatabase = userDatabase
        let editionRepo: any MushafEditionRepositoryProtocol = editionRepository ?? (try? MushafEditionDatabaseService()) ?? LegacyMushafAdapter(quranService: repository)
        self.editionRepository = editionRepo
        self.locationResolver = ReaderLocationResolver(repository: editionRepo)
        self.audioService = AudioPlayerService(repository: repository)
        self.currentPageIndex = max(1, initialPage)
        setupAudioSync()
    }

    // MARK: - Audio Sync
    private func setupAudioSync() {
        audioService.onVerseChanged = { [weak self] surahId, verseNumber in
            Task { @MainActor in
                await self?.handleAudioVerseChanged(surahId: surahId, verseNumber: verseNumber)
            }
        }
    }

    private func handleAudioVerseChanged(surahId: Int, verseNumber: Int) async {
        guard let key = VerseKey(surah: surahId, ayah: verseNumber) else { return }
        self.playingVerseKeyObj = key

        // Check if verse appears on the current page
        let currentPageId = currentPageSummary?.id ?? ""
        let isPresentOnCurrentPage = pageContentCache[currentPageId]?.verses.contains(where: { $0.verseKey == key }) ?? false

        if !isPresentOnCurrentPage {
            // Find destination page for this verse in the active edition
            do {
                let locations = try await editionRepository.fetchLocations(editionId: activeEditionId, verse: key)
                if let target = locations.first {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        self.currentPageIndex = target.navigationIndex
                    }
                }
            } catch {
                print("Failed to navigate for audio: \(error)")
            }
        }

        // Preload Ayah details for quick sheet access
        if selectedTaskOrSheetIdle {
            if let ayah = try? await repository.fetchAyah(surah: surahId, verse: verseNumber) {
                self.selectedAyah = ayah
                self.selectedVerseKey = ayah.verseKey
                self.selectedVerseKeyObj = key
            }
        }
    }

    private var selectedTaskOrSheetIdle: Bool {
        selectionTask == nil && !isTranslationSheetPresented
    }

    // MARK: - Page Index Changed
    private func onPageIndexChanged(from oldIndex: Int, to newIndex: Int) {
        dismissAyahSelection()
        pageLoadTask?.cancel()
        pageLoadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadSurroundingPages()
        }
        scheduleLastReadAutoSave()
        Task { await checkCurrentPageBookmarked() }
    }

    // MARK: - Lifecycle
    public func onAppear() async {
        if surahs.isEmpty || pages.isEmpty {
            isLoading = true
            do {
                async let fetchedSurahs = repository.fetchSurahs()
                async let fetchedJuzs = repository.fetchJuzs()
                async let fetchedPages = editionRepository.fetchPages(editionId: activeEditionId)

                let (s, j, p) = try await (fetchedSurahs, fetchedJuzs, fetchedPages)
                self.surahs = s
                self.surahsByID = Dictionary(uniqueKeysWithValues: s.map { ($0.id, $0) })
                self.juzs = j
                self.pages = p

                // Clamp current index within loaded pages
                if !p.isEmpty {
                    let clamped = max(1, min(p.count, currentPageIndex))
                    self.currentPageIndex = clamped
                }

                await loadSurroundingPages()
                isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
        await refreshBookmarks()
    }

    // MARK: - Navigation
    public func jumpToPage(_ index: Int) {
        let maxPages = pages.isEmpty ? 848 : pages.count
        let clamped = max(1, min(maxPages, index))
        self.currentPageIndex = clamped
    }

    public func jumpToQuranOrdinal(_ ordinal: Int) {
        if let match = pages.first(where: { $0.quranOrdinal == ordinal }) {
            self.currentPageIndex = match.navigationIndex
        } else {
            jumpToPage(ordinal)
        }
    }

    public func jumpToSurah(_ surah: Surah) {
        Task {
            do {
                let loc = try await locationResolver.resolve(
                    destination: .surah(surahId: surah.id, ayahNumber: 1),
                    editionId: activeEditionId
                )
                self.currentPageIndex = loc.navigationIndex
            } catch {
                jumpToQuranOrdinal(surah.startPage)
            }
        }
    }

    public func jumpToJuz(_ juz: Juz) {
        Task {
            do {
                let loc = try await locationResolver.resolve(
                    destination: .juz(juzNumber: juz.id),
                    editionId: activeEditionId
                )
                self.currentPageIndex = loc.navigationIndex
            } catch {
                jumpToQuranOrdinal(juz.startPage)
            }
        }
    }

    public func jumpTo(destination: ReaderDestination) async {
        do {
            let loc = try await locationResolver.resolve(destination: destination, editionId: activeEditionId)
            self.currentPageIndex = loc.navigationIndex
            if let focused = loc.focusedVerse {
                beginSelectingAyah(surahId: focused.surah, verseNumber: focused.ayah)
            }
        } catch {
            print("Failed to resolve destination: \(error)")
        }
    }

    // MARK: - Ayah Selection
    public func selectAyahKey(_ key: VerseKey) {
        beginSelectingAyah(surahId: key.surah, verseNumber: key.ayah)
    }

    public func beginSelectingAyah(surahId: Int, verseNumber: Int) {
        selectionTask?.cancel()
        translationTask?.cancel()
        selectionGeneration += 1
        translationGeneration += 1
        let generation = selectionGeneration
        let key = "\(surahId):\(verseNumber)"
        let verseKeyObj = VerseKey(surah: surahId, ayah: verseNumber)

        selectedVerseKey = key
        selectedVerseKeyObj = verseKeyObj
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
            } catch {
                guard let self, !Task.isCancelled, self.selectionGeneration == generation else { return }
                self.dismissAyahSelection()
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func selectAyah(surahId: Int, verseNumber: Int) async {
        beginSelectingAyah(surahId: surahId, verseNumber: verseNumber)
        let pending = selectionTask
        await pending?.value
    }

    public func dismissAyahSelection() {
        if isTranslationSheetPresented {
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
        selectedVerseKeyObj = nil
        selectedAyah = nil
        activeAyahTranslation = nil
    }

    public func playAyah(_ ayah: Ayah) {
        audioService.play(surahId: ayah.surahId, verseNumber: ayah.verseNumber, surahName: currentSurahName)
        playingVerseKeyObj = VerseKey(surah: ayah.surahId, ayah: ayah.verseNumber)
        isTranslationSheetPresented = false
    }

    // MARK: - Bookmarks
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
            let pageId = currentPageSummary?.id ?? String(format: "p%04d", currentPage)
            let editionId = activeEditionId

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
                    // Also save to V2
                    let bookmarkV2 = ReaderBookmark(
                        id: 0,
                        editionId: editionId,
                        pageId: pageId,
                        anchorSurahId: a.surahId,
                        anchorVerseNumber: a.verseNumber,
                        title: title,
                        arabicSnippet: a.textClean,
                        translationSnippet: trans,
                        note: nil,
                        legacyPageNumber: a.pageNumber
                    )
                    _ = try? await userDatabase.addReaderBookmark(bookmarkV2)
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
        let pageId = currentPageSummary?.id ?? String(format: "p%04d", page)
        let editionId = activeEditionId

        Task {
            if isBookmarked {
                let title = "Page \(page) • \(sName) (Juz \(jNum))"
                _ = try? await userDatabase.addPageBookmark(pageNumber: page, title: title, note: nil)
                let bookmarkV2 = ReaderBookmark(
                    id: 0,
                    editionId: editionId,
                    pageId: pageId,
                    anchorSurahId: nil,
                    anchorVerseNumber: nil,
                    title: title,
                    arabicSnippet: nil,
                    translationSnippet: nil,
                    note: nil,
                    legacyPageNumber: page
                )
                _ = try? await userDatabase.addReaderBookmark(bookmarkV2)
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
        let currentLoc = ReaderLocation(
            editionId: activeEditionId,
            pageId: currentPageSummary?.id ?? String(format: "p%04d", currentPage),
            navigationIndex: currentPageIndex,
            quranOrdinal: currentPageSummary?.quranOrdinal,
            surahId: surahForPage(currentPage)?.id,
            juzNumber: currentJuzNumber,
            focusedVerse: nil,
            label: currentPageSummary?.printedLabel
        )
        lastReadSaveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self = self else { return }
            try? await self.userDatabase.saveLastReadPage(self.currentPage)
            try? await self.userDatabase.saveReaderLastLocation(currentLoc)
        }
    }

    // MARK: - Translation
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
        let centerIndex = currentPageIndex
        let targetIndices = [centerIndex, centerIndex - 1, centerIndex + 1].filter {
            $0 >= 1 && (pages.isEmpty || $0 <= pages.count)
        }

        // 1. Load edition page content and trigger image prefetching
        for idx in targetIndices {
            guard idx >= 1 && idx <= pages.count else { continue }
            let summary = pages[idx - 1]
            if pageContentCache[summary.id] == nil {
                if let content = try? await editionRepository.fetchPage(editionId: activeEditionId, pageId: summary.id) {
                    pageContentCache[summary.id] = content
                }
            }
        }

        #if canImport(UIKit)
        let neighborSummaries = targetIndices.compactMap { idx -> MushafPageSummary? in
            guard idx >= 1 && idx <= pages.count else { return nil }
            return pages[idx - 1]
        }
        await MushafImageLoader.shared.prefetch(pages: neighborSummaries)
        #endif

        // 2. Load ayahs and lines for text mode
        let currentOrdinal = currentPageSummary?.quranOrdinal ?? centerIndex
        let textTargets = [currentOrdinal, currentOrdinal - 1, currentOrdinal + 1].filter { (1...849).contains($0) }

        for p in textTargets {
            if pageAyahsCache[p] == nil {
                if let ayahs = try? await repository.fetchAyahs(forPage: p) {
                    pageAyahsCache[p] = ayahs
                }
            }
            if pageLinesCache[p] == nil {
                if let lines = try? await repository.fetchLines(forPage: p) {
                    pageLinesCache[p] = lines
                }
            }
        }
    }

    // MARK: - Display Mode & Chrome
    public func toggleDisplayMode() {
        withAnimation(.easeInOut(duration: 0.25)) {
            displayMode = (displayMode == .authenticFacsimile) ? .accessibleText : .authenticFacsimile
        }
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

    // MARK: - Helpers
    public var currentPageSummary: MushafPageSummary? {
        guard currentPageIndex >= 1 && currentPageIndex <= pages.count else { return nil }
        return pages[currentPageIndex - 1]
    }

    public func summaryForIndex(_ index: Int) -> MushafPageSummary? {
        guard index >= 1 && index <= pages.count else { return nil }
        return pages[index - 1]
    }

    public func surahForPage(_ page: Int) -> Surah? {
        if let summary = currentPageSummary,
           let content = pageContentCache[summary.id],
           let firstVerse = content.verses.first?.verseKey,
           let surah = surahsByID[firstVerse.surah] {
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
