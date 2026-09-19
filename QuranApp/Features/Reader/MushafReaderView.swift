//
//  MushafReaderView.swift
//  QuranApp
//
//  Main reading canvas implementing horizontal paging, auto-hiding chrome,
//  and bottom translation inspection sheet.
//

import SwiftUI

public struct MushafReaderView: View {
    @Bindable public var viewModel: MushafReaderViewModel

    public init(viewModel: MushafReaderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Chassis background
            AppColors.canvasVellum
                .ignoresSafeArea()

            // Horizontal Right-to-Left Paging Canvas
            TabView(selection: $viewModel.currentPage) {
                ForEach(1...849, id: \.self) { pageNum in
                    let surah = viewModel.surahForPage(pageNum)
                    let juz = viewModel.juzForPage(pageNum)

                    MushafPageView(
                        pageNumber: pageNum,
                        lines: viewModel.pageLinesCache[pageNum] ?? [],
                        surahName: surah?.englishName ?? "",
                        surahArabicName: surah?.arabicName ?? "",
                        juzNumber: juz?.id ?? 1,
                        juzArabicName: juz?.nameArabic ?? "",
                        revelationType: surah?.revelationType.rawValue,
                        totalVerses: surah?.totalVerses,
                        selectedVerseKey: viewModel.selectedVerseKey,
                        onSelectAyah: { surahId, ayahNumber in
                            Task { await viewModel.selectAyah(surahId: surahId, verseNumber: ayahNumber) }
                        }
                    )
                    .tag(pageNum)
                    .padding(.top, viewModel.isChromeVisible ? 60 : 4)
                    .padding(.bottom, viewModel.isChromeVisible ? 16 : 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleChrome()
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.layoutDirection, .rightToLeft) // Right-to-left Quranic paging

            // Top Navigation Bar Chrome
            if viewModel.isChromeVisible {
                VStack {
                    topChromeBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: $viewModel.isTranslationSheetPresented) {
            if let ayah = viewModel.selectedAyah {
                let surah = viewModel.surahs.first(where: { $0.id == ayah.surahId })
                AyahActionSheetView(
                    ayah: ayah,
                    surah: surah,
                    translation: viewModel.activeAyahTranslation,
                    isBookmarked: viewModel.bookmarks.contains(ayah.id),
                    onPlay: {
                        viewModel.isTranslationSheetPresented = false
                    },
                    onBookmark: {
                        viewModel.toggleBookmark(ayahId: ayah.id)
                    },
                    onSelectAuthor: { author in
                        Task { await viewModel.changeTranslationAuthor(author) }
                    }
                )
                .presentationDetents([.fraction(0.44), .medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $viewModel.isBookmarksSheetPresented) {
            BookmarksListView(
                userDatabase: viewModel.userDatabase,
                currentPage: viewModel.currentPage,
                onSelectBookmark: { bookmark in
                    viewModel.jumpToPage(bookmark.pageNumber)
                    if let sId = bookmark.surahId, let vNum = bookmark.verseNumber {
                        Task {
                            await viewModel.selectAyah(surahId: sId, verseNumber: vNum)
                        }
                    }
                },
                onDismiss: {
                    viewModel.isBookmarksSheetPresented = false
                }
            )
        }
    }

    // MARK: - Top Chrome Bar
    private var topChromeBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSurahName)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.inkUmber)
                Text("Juz \(viewModel.currentJuzNumber) • Page \(viewModel.currentPage) of 849")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)
            }

            Spacer()

            HStack(spacing: 4) {
                // Bookmarks List Button (44x44pt)
                Button(action: {
                    viewModel.isBookmarksSheetPresented = true
                }) {
                    Image(systemName: viewModel.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.isCurrentPageBookmarked ? AppColors.saddleAmber : AppColors.sepiaMuted)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(viewModel.isCurrentPageBookmarked ? "Bookmarks (Page \(viewModel.currentPage) bookmarked)" : "Bookmarks")

                // Translation Switcher Capsule
                Menu {
                    Button("Saheeh International") {
                        viewModel.selectedTranslationAuthor = .saheeh
                    }
                    Button("Dr. Hilali & Dr. Muhsin Khan") {
                        viewModel.selectedTranslationAuthor = .hilaliKhan
                    }
                    Button("Hamidullah (Français)") {
                        viewModel.selectedTranslationAuthor = .hamidullah
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 13))
                        Text(viewModel.selectedTranslationAuthor == .saheeh ? "Saheeh" : (viewModel.selectedTranslationAuthor == .hilaliKhan ? "Hilali-Khan" : "Français"))
                            .font(AppTypography.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.surfacePapyrus)
                    .foregroundStyle(AppColors.saddleAmber)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.borderSepia, lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.paperAged.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 12)
    }
}
