//
//  IndexHubView.swift
//  QuranApp
//
//  Complete, Stitch-accurate Surahs & Juz Navigation Index with FTS5 live search,
//  debounced query execution, 44pt touch targets, and full accessibility compliance.
//

import SwiftUI

public struct IndexHubView: View {
    @State private var viewModel: IndexViewModel
    public let currentReadingPage: Int
    public let onSelectPage: (Int) -> Void
    public let onSelectAyah: ((Int, Int, Int) -> Void)?

    public init(
        repository: QuranRepositoryProtocol,
        currentReadingPage: Int = 1,
        onSelectPage: @escaping (Int) -> Void,
        onSelectAyah: ((Int, Int, Int) -> Void)? = nil
    ) {
        _viewModel = State(wrappedValue: IndexViewModel(repository: repository))
        self.currentReadingPage = currentReadingPage
        self.onSelectPage = onSelectPage
        self.onSelectAyah = onSelectAyah
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Top Header & Controls
                VStack(spacing: 10) {
                    // Header Title Bar
                    headerTitleBar

                    // Recessed Search Pill
                    searchBar

                    // 3-Pill Segmented Control (Surahs / Juz / Pages)
                    if viewModel.searchText.isEmpty {
                        segmentedControl
                        metadataBar
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(AppColors.canvasVellum)

                Divider().overlay(AppColors.borderSepia)

                // MARK: - Main Content Area
                ZStack {
                    AppColors.canvasVellum.ignoresSafeArea()

                    if !viewModel.searchText.isEmpty {
                        searchContent
                    } else {
                        switch viewModel.selectedTab {
                        case .surahs:
                            surahContent
                        case .juz:
                            juzContent
                        case .pages:
                            PageJumpView(juzs: viewModel.juzs) { targetPage in
                                onSelectPage(targetPage)
                            }
                        }
                    }
                }
            }
            .background(AppColors.canvasVellum)
            .navigationBarHidden(true)
            .task {
                await viewModel.onAppear()
            }
        }
    }

    // MARK: - Header Title Bar
    private var headerTitleBar: some View {
        HStack {
            // Left ornamental space (for centering)
            Color.clear.frame(width: 44, height: 44)

            Spacer()

            // Center Title
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Text("❖")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.saddleAmber)
                    Text("Surahs & Juz")
                        .font(.system(size: 18, weight: .semibold, design: .serif))
                        .foregroundStyle(AppColors.inkUmber)
                    Text("❖")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.saddleAmber)
                }

                Text("فِهْرِسُ المُصْحَفِ الشَّرِيف")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.sepiaMuted)
            }

            Spacer()

            // Right: Sort Menu Button (44x44pt)
            Menu {
                Picker("Sort Order", selection: $viewModel.sortOrder) {
                    ForEach(IndexViewModel.SortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.saddleAmber)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Sort options")
        }
        .frame(height: 44)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(AppColors.sepiaMuted)

            TextField("Search surah, meaning, or verse...", text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.updateSearch($0) }
            ))
            .font(AppTypography.body)
            .foregroundStyle(AppColors.inkUmber)
            .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.clearSearch() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.sepiaMuted)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            } else {
                Text("13-line")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.sepiaMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.paperAged)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.borderSepia, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(AppColors.surfacePapyrus.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.borderSepia, lineWidth: 1))
    }

    // MARK: - Segmented Control (Pill Switcher)
    private var segmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(IndexViewModel.IndexTab.allCases, id: \.self) { tab in
                let isSelected = viewModel.selectedTab == tab
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        viewModel.selectedTab = tab
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 12))

                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))

                        Text(badgeCount(for: tab))
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.white.opacity(0.25) : AppColors.borderSepia.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .foregroundStyle(isSelected ? Color.white : AppColors.sepiaMuted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 38)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.saddleAmber)
                                    .shadow(color: AppColors.saddleAmber.opacity(0.25), radius: 3, y: 1)
                            } else {
                                Color.clear
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(minHeight: 44) // 44pt touch target standard
                .accessibilityLabel("\(tab.rawValue) tab, \(badgeCount(for: tab)) items")
            }
        }
        .padding(3)
        .background(AppColors.surfacePapyrus)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.borderSepia, lineWidth: 1))
    }

    // MARK: - Metadata Bar
    private var metadataBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.saddleAmber)
                    .frame(width: 6, height: 6)
                Text("114 SURAHS • CLASSICAL LITHOGRAPH")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(AppColors.sepiaMuted)
            }

            Spacer()

            Text("Sort: \(viewModel.sortOrder.rawValue)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.saddleAmber)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Surah List Content
    private var surahContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.sortedSurahs) { surah in
                    let isReading = isSurahCurrentlyReading(surah)
                    SurahRowView(
                        surah: surah,
                        juzSpan: viewModel.juzSpan(for: surah.id),
                        isCurrentlyReading: isReading,
                        onSelect: {
                            onSelectPage(surah.startPage)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Juz List Content
    private var juzContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.juzs) { juz in
                    let surahName = viewModel.surahs.first(where: { $0.id == juz.startSurahId })?.englishName ?? "Quran"
                    JuzRowView(
                        juz: juz,
                        startingSurahName: surahName,
                        onSelect: {
                            onSelectPage(juz.startPage)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Search Content
    private var searchContent: some View {
        Group {
            if viewModel.isSearching {
                VStack(spacing: 12) {
                    Spacer().frame(height: 60)
                    ProgressView()
                        .tint(AppColors.saddleAmber)
                    Text("Searching across the Holy Quran...")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.sepiaMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 10) {
                    Spacer().frame(height: 60)
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundStyle(AppColors.sepiaMuted.opacity(0.6))
                    Text("No verses found matching \"\(viewModel.searchText)\"")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.inkUmber)
                    Text("Try searching in English, French, or normalized Arabic")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.sepiaMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        HStack {
                            Text("\(viewModel.searchResults.count) results found")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.sepiaMuted)
                            Spacer()
                        }
                        .padding(.horizontal, 4)

                        ForEach(viewModel.searchResults) { result in
                            SearchResultRowView(
                                result: result,
                                searchQuery: viewModel.searchText,
                                onSelect: {
                                    if let onSelectAyah = onSelectAyah {
                                        onSelectAyah(result.surahId, result.verseNumber, result.pageNumber)
                                    } else {
                                        onSelectPage(result.pageNumber)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Helpers
    private func iconName(for tab: IndexViewModel.IndexTab) -> String {
        switch tab {
        case .surahs: return "book.pages"
        case .juz: return "bookmark"
        case .pages: return "square.grid.3x3"
        }
    }

    private func badgeCount(for tab: IndexViewModel.IndexTab) -> String {
        switch tab {
        case .surahs: return "\(viewModel.surahs.count)"
        case .juz: return "\(viewModel.juzs.count)"
        case .pages: return "849"
        }
    }

    private func isSurahCurrentlyReading(_ surah: Surah) -> Bool {
        guard let nextSurah = viewModel.surahs.first(where: { $0.id == surah.id + 1 }) else {
            return currentReadingPage >= surah.startPage
        }
        return currentReadingPage >= surah.startPage && currentReadingPage < nextSurah.startPage
    }
}
