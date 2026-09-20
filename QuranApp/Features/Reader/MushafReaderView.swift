//
//  MushafReaderView.swift
//  QuranApp
//
//  Native RTL paging and SwiftUI chrome/sheets around the fixed-page renderer.
//

import SwiftUI

@MainActor
public struct MushafReaderView: View {
    @Bindable public var viewModel: MushafReaderViewModel
    public let palette: ThemePalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(viewModel: MushafReaderViewModel, palette: ThemePalette = AppColors.palette(for: .sepia)) {
        self.viewModel = viewModel
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            palette.canvasVellum.ignoresSafeArea()
            TabView(selection: $viewModel.currentPage) {
                ForEach(1...849, id: \.self) { page in
                    Group {
                        if abs(page - viewModel.currentPage) <= 1 {
                            pageView(page)
                        } else {
                            Color.clear
                        }
                    }
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .environment(\.layoutDirection, .rightToLeft)
            .safeAreaInset(edge: .top, spacing: 0) {
                if viewModel.isChromeVisible {
                    topChromeBar
                        .padding(.vertical, 4)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .task { await viewModel.onAppear() }
        .sheet(isPresented: $viewModel.isTranslationSheetPresented) {
            ayahSheet
                .presentationDetents([.fraction(0.44), .medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.isBookmarksSheetPresented) {
            BookmarksListView(
                userDatabase: viewModel.userDatabase,
                currentPage: viewModel.currentPage,
                onSelectBookmark: { bookmark in
                    viewModel.jumpToPage(bookmark.pageNumber)
                    if let surah = bookmark.surahId, let verse = bookmark.verseNumber {
                        viewModel.beginSelectingAyah(surahId: surah, verseNumber: verse)
                    }
                },
                onDismiss: { viewModel.isBookmarksSheetPresented = false }
            )
        }
        .alert("Reader", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func pageView(_ page: Int) -> some View {
        let surah = viewModel.surahForPage(page)
        let juz = viewModel.juzForPage(page)
        return MushafPageView(
            pageNumber: page,
            lines: viewModel.pageLinesCache[page] ?? [],
            surahName: surah?.englishName ?? "",
            surahArabicName: surah?.arabicName ?? "",
            juzNumber: juz?.id ?? 1,
            juzArabicName: juz?.nameArabic ?? "",
            surahMetadata: viewModel.surahsByID,
            selectedVerseKey: viewModel.selectedVerseKey,
            palette: palette,
            onSelectAyah: { surah, verse in
                viewModel.beginSelectingAyah(surahId: surah, verseNumber: verse)
            },
            onToggleChrome: { viewModel.toggleChrome(reduceMotion: reduceMotion) }
        )
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var ayahSheet: some View {
        if let ayah = viewModel.selectedAyah {
            AyahActionSheetView(
                ayah: ayah,
                surah: viewModel.surahsByID[ayah.surahId],
                translation: viewModel.activeAyahTranslation,
                isBookmarked: viewModel.bookmarks.contains(ayah.id),
                onPlay: { viewModel.isTranslationSheetPresented = false },
                onBookmark: { viewModel.toggleBookmark(ayahId: ayah.id) },
                onSelectAuthor: { author in
                    Task { await viewModel.changeTranslationAuthor(author) }
                }
            )
        } else {
            ProgressView("Loading verse…")
        }
    }

    private var topChromeBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSurahName)
                    .font(AppTypography.headline)
                    .foregroundStyle(palette.inkUmber)
                    .lineLimit(1)
                Text("Juz \(viewModel.currentJuzNumber) • Page \(viewModel.currentPage) of 849")
                    .font(.caption2)
                    .foregroundStyle(palette.sepiaMuted)
            }
            Spacer(minLength: 0)
            Button { viewModel.isBookmarksSheetPresented = true } label: {
                Image(systemName: viewModel.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(viewModel.isCurrentPageBookmarked ? palette.saddleAmber : palette.sepiaMuted)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Bookmarks")
            .accessibilityIdentifier("reader-bookmarks")

            Menu {
                ForEach(Translation.TranslationAuthor.allCases, id: \.self) { author in
                    Button(author.displayName) { viewModel.selectedTranslationAuthor = author }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "character.book.closed.fill")
                    Text(translationLabel).font(.caption)
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(palette.surfacePapyrus, in: Capsule())
                .foregroundStyle(palette.saddleAmber)
                .overlay(Capsule().stroke(palette.borderSepia, lineWidth: 1))
            }
            .accessibilityLabel("Translation: \(viewModel.selectedTranslationAuthor.displayName)")
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.paperAged.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 10)
        .accessibilityIdentifier("reader-chrome")
    }

    private var translationLabel: String {
        switch viewModel.selectedTranslationAuthor {
        case .saheeh: return "Saheeh"
        case .hilaliKhan: return "Hilali-Khan"
        case .hamidullah: return "Français"
        }
    }
}
