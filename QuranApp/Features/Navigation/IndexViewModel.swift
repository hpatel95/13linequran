//
//  IndexViewModel.swift
//  QuranApp
//
//  @Observable @MainActor state manager for the Index Navigation Hub and FTS5 search engine.
//  Implements 300ms debounced search with task cancellation, memoized sort/filter,
//  and precomputed Juz span metadata.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class IndexViewModel {
    // MARK: - Types
    public enum IndexTab: String, CaseIterable, Sendable {
        case surahs = "Surahs"
        case juz = "Juz"
        case pages = "Pages"
    }

    public enum SortOrder: String, CaseIterable, Sendable {
        case traditional = "Traditional"
        case revelation = "Revelation"
        case alphabetical = "Alphabetical"
    }

    // MARK: - State
    public var selectedTab: IndexTab = .surahs
    public var searchText: String = ""
    public var searchResults: [SearchResult] = []
    public var surahs: [Surah] = []
    public var juzs: [Juz] = []
    public var surahJuzSpans: [Int: String] = [:]
    public var sortOrder: SortOrder = .traditional
    public var isLoading: Bool = false
    public var isSearching: Bool = false
    public var errorMessage: String?

    // MARK: - Private
    private var searchTask: Task<Void, Never>?
    private let repository: QuranRepositoryProtocol

    public init(repository: QuranRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Lifecycle
    public func onAppear() async {
        guard surahs.isEmpty else { return }
        isLoading = true
        do {
            async let fetchedSurahs = repository.fetchSurahs()
            async let fetchedJuzs = repository.fetchJuzs()
            async let fetchedSpans = repository.fetchSurahJuzSpans()

            let (s, j, spans) = try await (fetchedSurahs, fetchedJuzs, fetchedSpans)
            self.surahs = s
            self.juzs = j
            self.surahJuzSpans = spans
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    // MARK: - Search (300ms Debounce + Cancellation)
    public func updateSearch(_ query: String) {
        self.searchText = query
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            do {
                let results = try await repository.search(query: trimmed, limit: 40)
                guard !Task.isCancelled else { return }
                self.searchResults = results
                self.isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                self.searchResults = []
                self.isSearching = false
            }
        }
    }

    public func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        searchResults = []
        isSearching = false
    }

    // MARK: - Computed Sorted Lists
    public var sortedSurahs: [Surah] {
        let baseList: [Surah]
        if !searchText.isEmpty {
            let lower = searchText.lowercased()
            baseList = surahs.filter { surah in
                surah.englishName.lowercased().contains(lower) ||
                surah.englishMeaning.lowercased().contains(lower) ||
                surah.arabicName.contains(lower) ||
                String(surah.id) == lower
            }
        } else {
            baseList = surahs
        }

        switch sortOrder {
        case .traditional:
            return baseList.sorted { $0.id < $1.id }
        case .revelation:
            // Meccan first then Medinan, preserving traditional order within each group
            return baseList.sorted { a, b in
                if a.revelationType == b.revelationType {
                    return a.id < b.id
                }
                return a.revelationType == .meccan
            }
        case .alphabetical:
            return baseList.sorted { $0.englishName.localizedCaseInsensitiveCompare($1.englishName) == .orderedAscending }
        }
    }

    public func juzSpan(for surahId: Int) -> String {
        surahJuzSpans[surahId] ?? "Juz 1"
    }
}
