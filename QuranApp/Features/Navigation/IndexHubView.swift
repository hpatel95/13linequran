//
//  IndexHubView.swift
//  QuranApp
//
//  Surah & Juz navigation index based directly on the Stitch "Index Hub" screen.
//  Provides instant search via FTS5 full-text search.
//

import SwiftUI

public struct IndexHubView: View {
    @State private var selectedTab: IndexTab = .surahs
    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var surahs: [Surah] = []
    @State private var isLoading: Bool = false

    public let repository: QuranRepositoryProtocol
    public let onSelectPage: (Int) -> Void

    public enum IndexTab: String, CaseIterable {
        case surahs = "Surahs"
        case juz = "Juz"
        case search = "Search"
    }

    public init(
        repository: QuranRepositoryProtocol,
        onSelectPage: @escaping (Int) -> Void
    ) {
        self.repository = repository
        self.onSelectPage = onSelectPage
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header & Segment Picker
                VStack(spacing: 12) {
                    Picker("Category", selection: $selectedTab) {
                        ForEach(IndexTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Search field (always visible or in search tab)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppColors.sepiaMuted)
                        TextField("Search Surah, text or meaning...", text: $searchText)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.inkUmber)
                            .onChange(of: searchText) { _, newValue in
                                Task { await performSearch(query: newValue) }
                            }
                        if !searchText.isEmpty {
                            Button(action: { searchText = ""; searchResults = [] }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.sepiaMuted)
                            }
                        }
                    }
                    .padding(10)
                    .background(AppColors.surfacePapyrus)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.borderSepia, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.canvasVellum)

                Divider().overlay(AppColors.borderSepia)

                // Tab Content
                if !searchText.isEmpty || selectedTab == .search {
                    searchListView
                } else if selectedTab == .surahs {
                    surahListView
                } else {
                    juzListView
                }
            }
            .background(AppColors.paperAged)
            .navigationTitle("Index")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if surahs.isEmpty {
                    surahs = (try? await repository.fetchSurahs()) ?? []
                }
            }
        }
    }

    // MARK: - Surahs List
    private var surahListView: some View {
        List {
            ForEach(surahs) { surah in
                Button(action: { onSelectPage(surah.startPage) }) {
                    HStack(spacing: 14) {
                        // Surah Number Pill
                        Text(String(format: "%03d", surah.id))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.saddleAmber)
                            .frame(width: 36, height: 36)
                            .background(AppColors.surfacePapyrus)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // English Details
                        VStack(alignment: .leading, spacing: 2) {
                            Text(surah.englishName)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.inkUmber)
                            Text("\(surah.englishMeaning) • \(surah.totalVerses) verses")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.sepiaMuted)
                        }

                        Spacer()

                        // Arabic Title & Page
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(surah.arabicName)
                                .font(AppTypography.surahHeader)
                                .foregroundStyle(AppColors.inkUmber)
                            Text("Page \(surah.startPage)")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.saddleAmber)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppColors.paperAged)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Juz List
    private var juzListView: some View {
        List {
            ForEach(1...30, id: \.self) { juzNum in
                let surah = surahs.first(where: { $0.juzNumber == juzNum }) ?? surahs.first
                let page = surah?.startPage ?? 1

                Button(action: { onSelectPage(page) }) {
                    HStack(spacing: 14) {
                        Text("\(juzNum)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.saddleAmber)
                            .frame(width: 36, height: 36)
                            .background(AppColors.surfacePapyrus)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Juz \(juzNum)")
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.inkUmber)
                            Text(surah?.englishName ?? "Al-Quran")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.sepiaMuted)
                        }

                        Spacer()

                        Text("Page \(page)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.saddleAmber)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(AppColors.paperAged)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Search Results
    private var searchListView: some View {
        List {
            if searchResults.isEmpty {
                VStack(spacing: 8) {
                    Spacer().frame(height: 40)
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.sepiaMuted)
                    Text(searchText.isEmpty ? "Type a word to search across the Quran" : "No verses found matching \"\(searchText)\"")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.sepiaMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            } else {
                ForEach(searchResults) { result in
                    Button(action: {
                        // Look up page for verse
                        Task {
                            if let ayah = try? await repository.fetchAyah(surah: result.surahId, verse: result.verseNumber) {
                                onSelectPage(ayah.pageNumber)
                            }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Surah \(result.surahId):\(result.verseNumber)")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.saddleAmber)
                                Spacer()
                            }

                            Text(result.arabicClean)
                                .font(AppTypography.arabic13Line)
                                .foregroundStyle(AppColors.inkUmber)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .environment(\.layoutDirection, .rightToLeft)

                            Text(result.translationEnSaheeh)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.sepiaMuted)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(AppColors.paperAged)
                }
            }
        }
        .listStyle(.plain)
    }

    private func performSearch(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        do {
            searchResults = try await repository.search(query: query, limit: 25)
        } catch {
            searchResults = []
        }
    }
}
