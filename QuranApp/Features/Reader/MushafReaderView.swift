//
//  MushafReaderView.swift
//  QuranApp
//
//  Native RTL paging, authentic facsimile scanned lithographs, accessible text mode,
//  and SwiftUI top/bottom chrome around the authentic 13-line reader.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
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

            // RTL Paging Canvas
            tabViewContent
                .tabViewStyle(.page(indexDisplayMode: .never))
                .environment(\.layoutDirection, .rightToLeft)

            // Top Chrome Bar
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
                    viewModel.jumpToQuranOrdinal(bookmark.pageNumber)
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

    // MARK: - TabView Content
    private var tabViewContent: some View {
        let totalPages = max(1, viewModel.pages.isEmpty ? 848 : viewModel.pages.count)
        return TabView(selection: $viewModel.currentPageIndex) {
            ForEach(1...totalPages, id: \.self) { index in
                Group {
                    if abs(index - viewModel.currentPageIndex) <= 1 {
                        if let summary = viewModel.summaryForIndex(index) {
                            pageContent(summary: summary, index: index)
                        } else {
                            fallbackLoadingPage(index: index)
                        }
                    } else {
                        Color.clear
                    }
                }
                .tag(index)
            }
        }
    }

    // MARK: - Page Content
    @ViewBuilder
    private func pageContent(summary: MushafPageSummary, index: Int) -> some View {
        switch viewModel.displayMode {
        case .authenticFacsimile:
            AuthenticMushafPageView(
                summary: summary,
                content: viewModel.pageContentCache[summary.id],
                selectedVerse: viewModel.selectedVerseKeyObj,
                playingVerse: viewModel.playingVerseKeyObj,
                palette: palette,
                onSelectAyah: { verseKey in
                    viewModel.selectAyahKey(verseKey)
                },
                onToggleChrome: {
                    viewModel.toggleChrome(reduceMotion: reduceMotion)
                }
            )

        case .accessibleText:
            let pageOrdinal = summary.quranOrdinal ?? index
            MushafPageTextView(
                summary: summary,
                verses: viewModel.pageAyahsCache[pageOrdinal] ?? [],
                surahs: viewModel.surahsByID,
                selectedVerse: viewModel.selectedVerseKeyObj,
                playingVerse: viewModel.playingVerseKeyObj,
                palette: palette,
                onSelectAyah: { verseKey in
                    viewModel.selectAyahKey(verseKey)
                },
                onToggleChrome: {
                    viewModel.toggleChrome(reduceMotion: reduceMotion)
                }
            )
        }
    }

    private func fallbackLoadingPage(index: Int) -> some View {
        ZStack {
            palette.canvasVellum.ignoresSafeArea()
            ProgressView()
                .tint(palette.saddleAmber)
        }
    }

    // MARK: - Ayah Bottom Sheet
    @ViewBuilder
    private var ayahSheet: some View {
        if let ayah = viewModel.selectedAyah {
            AyahActionSheetView(
                ayah: ayah,
                surah: viewModel.surahsByID[ayah.surahId],
                translation: viewModel.activeAyahTranslation,
                isBookmarked: viewModel.bookmarks.contains(ayah.id),
                onPlay: {
                    viewModel.playAyah(ayah)
                },
                onBookmark: {
                    viewModel.toggleBookmark(ayahId: ayah.id)
                },
                onSelectAuthor: { author in
                    Task { await viewModel.changeTranslationAuthor(author) }
                }
            )
        } else {
            ProgressView("Loading verse…")
        }
    }

    // MARK: - Top Chrome Bar
    private var topChromeBar: some View {
        HStack(spacing: 8) {
            // Surah & Page info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentSurahName)
                    .font(AppTypography.headline)
                    .foregroundStyle(palette.inkUmber)
                    .lineLimit(1)

                let subtitle: String = {
                    if let ordinal = viewModel.currentPageSummary?.quranOrdinal {
                        return "Juz \(viewModel.currentJuzNumber) • Page \(ordinal) of 847"
                    } else if let title = viewModel.currentPageSummary?.title {
                        return "Juz \(viewModel.currentJuzNumber) • \(title)"
                    } else {
                        return "Juz \(viewModel.currentJuzNumber) • Page \(viewModel.currentPageIndex)"
                    }
                }()

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(palette.sepiaMuted)
            }

            Spacer(minLength: 0)

            // Display Mode Switcher (Authentic Facsimile vs Accessible Text)
            Button {
                viewModel.toggleDisplayMode()
            } label: {
                Image(systemName: viewModel.displayMode == .authenticFacsimile ? "text.aligncenter" : "doc.text.image")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.inkUmber)
                    .frame(minWidth: 40, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Switch reader mode (currently \(viewModel.displayMode.rawValue))")
            .accessibilityIdentifier("reader-mode-toggle")

            // Bookmark Page Button
            Button {
                viewModel.isBookmarksSheetPresented = true
            } label: {
                Image(systemName: viewModel.isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(viewModel.isCurrentPageBookmarked ? palette.saddleAmber : palette.sepiaMuted)
                    .frame(minWidth: 40, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Bookmarks")
            .accessibilityIdentifier("reader-bookmarks")

            // Translation Switcher Menu
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
