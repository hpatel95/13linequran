//
//  BookmarksListView.swift
//  QuranApp
//
//  Modal bottom sheet presenting all saved Ayah and Page bookmarks with filter pills,
//  native swipe-to-delete, optimistic deletion, empty state guidance, and direct reader navigation.
//

import SwiftUI

public struct BookmarksListView: View {
    public let userDatabase: UserDatabaseServiceProtocol
    public let currentPage: Int
    public let onSelectBookmark: (Bookmark) -> Void
    public let onDismiss: () -> Void

    @State private var bookmarks: [Bookmark] = []
    @State private var selectedFilter: BookmarkFilter = .all
    @State private var isLoading: Bool = true
    @State private var isCurrentPageBookmarked: Bool = false

    public enum BookmarkFilter: String, CaseIterable, Sendable {
        case all = "All"
        case verses = "Verses"
        case pages = "Pages"
    }

    public init(
        userDatabase: UserDatabaseServiceProtocol,
        currentPage: Int,
        onSelectBookmark: @escaping (Bookmark) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.userDatabase = userDatabase
        self.currentPage = currentPage
        self.onSelectBookmark = onSelectBookmark
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header Bar
                headerBar

                // MARK: - Quick Page Bookmark Banner
                quickPageBookmarkBanner

                // MARK: - Filter Pills
                if !bookmarks.isEmpty {
                    filterPills
                }

                Divider().overlay(AppColors.borderSepia)

                // MARK: - Content List or Empty State
                ZStack {
                    AppColors.canvasVellum.ignoresSafeArea()

                    if isLoading {
                        ProgressView()
                            .tint(AppColors.saddleAmber)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredBookmarks.isEmpty {
                        emptyStateView
                    } else {
                        bookmarksList
                    }
                }
            }
            .background(AppColors.canvasVellum)
            .navigationBarHidden(true)
            .task {
                await loadBookmarks()
            }
        }
        .presentationDetents([.fraction(0.60), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.saddleAmber)
                Text("Saved Bookmarks")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(AppColors.inkUmber)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColors.sepiaMuted)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Close bookmarks")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(AppColors.canvasVellum)
    }

    // MARK: - Quick Page Bookmark Banner
    private var quickPageBookmarkBanner: some View {
        HStack {
            Button(action: toggleCurrentPage) {
                HStack(spacing: 8) {
                    Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13))
                        .foregroundStyle(isCurrentPageBookmarked ? .white : AppColors.saddleAmber)

                    Text(isCurrentPageBookmarked ? "Page \(currentPage) Bookmarked" : "Bookmark Current Page (p. \(currentPage))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isCurrentPageBookmarked ? .white : AppColors.inkUmber)

                    Spacer()

                    if isCurrentPageBookmarked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isCurrentPageBookmarked ? AppColors.saddleAmber : AppColors.surfacePapyrus.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isCurrentPageBookmarked ? AppColors.saddleAmber : AppColors.borderSepia, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Filter Pills
    private var filterPills: some View {
        HStack(spacing: 8) {
            ForEach(BookmarkFilter.allCases, id: \.self) { filter in
                let count = countForFilter(filter)
                let isSelected = selectedFilter == filter
                Button(action: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        selectedFilter = filter
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        Text("\(count)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.white.opacity(0.25) : AppColors.borderSepia.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .foregroundStyle(isSelected ? Color.white : AppColors.sepiaMuted)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(
                        Group {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 8).fill(AppColors.saddleAmber)
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(AppColors.surfacePapyrus.opacity(0.7))
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? AppColors.saddleAmber : AppColors.borderSepia, lineWidth: 0.5)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(minHeight: 44)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Bookmarks List
    private var bookmarksList: some View {
        List {
            ForEach(filteredBookmarks) { bookmark in
                BookmarkRowView(bookmark: bookmark) {
                    onSelectBookmark(bookmark)
                    onDismiss()
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteBookmark(bookmark)
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }
                }
                .accessibilityAction(named: "Delete Bookmark") {
                    deleteBookmark(bookmark)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 4)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)

            Image(systemName: "bookmark")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.sepiaMuted.opacity(0.5))

            Text("No Bookmarks Yet")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .foregroundStyle(AppColors.inkUmber)

            Text("Tap any Ayah in the reader to save it, or use the button above to bookmark Page \(currentPage).")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.sepiaMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filtered Bookmarks
    private var filteredBookmarks: [Bookmark] {
        switch selectedFilter {
        case .all:
            return bookmarks
        case .verses:
            return bookmarks.filter { !$0.isPageBookmark }
        case .pages:
            return bookmarks.filter { $0.isPageBookmark }
        }
    }

    private func countForFilter(_ filter: BookmarkFilter) -> Int {
        switch filter {
        case .all: return bookmarks.count
        case .verses: return bookmarks.filter { !$0.isPageBookmark }.count
        case .pages: return bookmarks.filter { $0.isPageBookmark }.count
        }
    }

    // MARK: - Actions
    private func loadBookmarks() async {
        isLoading = true
        do {
            self.bookmarks = try await userDatabase.fetchBookmarks()
            self.isCurrentPageBookmarked = try await userDatabase.isPageBookmarked(pageNumber: currentPage)
            self.isLoading = false
        } catch {
            print("Error loading bookmarks: \(error)")
            self.isLoading = false
        }
    }

    private func toggleCurrentPage() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        isCurrentPageBookmarked.toggle()
        let page = currentPage
        let isBookmarked = isCurrentPageBookmarked

        Task {
            if isBookmarked {
                _ = try? await userDatabase.addPageBookmark(pageNumber: page, title: "Page \(page) Bookmark", note: nil)
            } else {
                try? await userDatabase.removePageBookmark(pageNumber: page)
            }
            await loadBookmarks()
        }
    }

    private func deleteBookmark(_ bookmark: Bookmark) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        withAnimation(.spring(response: 0.4, dampingFraction: 1.0)) {
            bookmarks.removeAll { $0.id == bookmark.id }
        }

        Task {
            try? await userDatabase.removeBookmark(id: bookmark.id)
            if bookmark.isPageBookmark && bookmark.pageNumber == currentPage {
                self.isCurrentPageBookmarked = false
            }
        }
    }
}
