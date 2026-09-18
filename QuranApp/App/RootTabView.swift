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

    public enum TabItem: Hashable {
        case read
        case index
        case settings
    }

    public init(repository: QuranRepositoryProtocol) {
        _readerViewModel = State(wrappedValue: MushafReaderViewModel(repository: repository))
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Reader
            MushafReaderView(viewModel: readerViewModel)
                .tabItem {
                    Label("Read", systemImage: "book.pages.fill")
                }
                .tag(TabItem.read)

            // Tab 2: Index & Search
            IndexHubView(
                repository: readerViewModel.repository,
                onSelectPage: { targetPage in
                    readerViewModel.jumpToPage(targetPage)
                    selectedTab = .read
                }
            )
            .tabItem {
                Label("Index", systemImage: "list.bullet.rectangle.portrait.fill")
            }
            .tag(TabItem.index)

            // Tab 3: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(TabItem.settings)
        }
        .tint(AppColors.saddleAmber)
    }
}


