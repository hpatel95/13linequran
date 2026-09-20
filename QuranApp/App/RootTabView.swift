//
//  RootTabView.swift
//  QuranApp
//
//  Root 3-tab navigation shell combining the Reader, Index Hub, and Settings.
//

import SwiftUI

public struct RootTabView: View {
    @State private var selectedTab: TabItem = .read
    @State private var readerViewModel: MushafReaderViewModel

    public let downloadManager: DownloadManager
    public let themeManager: ThemeManager

    public enum TabItem: Hashable {
        case read
        case index
        case settings
    }

    public init(
        repository: QuranRepositoryProtocol,
        userDatabase: UserDatabaseServiceProtocol,
        downloadManager: DownloadManager,
        themeManager: ThemeManager,
        initialPage: Int = 1
    ) {
        self.downloadManager = downloadManager
        self.themeManager = themeManager
        _readerViewModel = State(wrappedValue: MushafReaderViewModel(
            repository: repository,
            userDatabase: userDatabase,
            initialPage: initialPage
        ))
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Reader
            MushafReaderView(viewModel: readerViewModel, palette: themeManager.colors)
                .tabItem {
                    Label("Read", systemImage: "book.pages.fill")
                }
                .tag(TabItem.read)

            // Tab 2: Index & Search
            IndexHubView(
                repository: readerViewModel.repository,
                currentReadingPage: readerViewModel.currentPage,
                onSelectPage: { targetPage in
                    readerViewModel.jumpToQuranOrdinal(targetPage)
                    selectedTab = .read
                },
                onSelectAyah: { surahId, verseNumber, pageNumber in
                    Task {
                        await readerViewModel.jumpTo(destination: .surah(surahId: surahId, ayahNumber: verseNumber))
                    }
                    selectedTab = .read
                }
            )
            .tabItem {
                Label("Index", systemImage: "list.bullet.rectangle.portrait.fill")
            }
            .tag(TabItem.index)

            // Tab 3: Settings
            SettingsView(downloadManager: downloadManager, themeManager: themeManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(TabItem.settings)
        }
        .tint(themeManager.colors.saddleAmber)
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .toolbar(selectedTab == .read && !readerViewModel.isChromeVisible ? .hidden : .visible, for: .tabBar)
    }
}


