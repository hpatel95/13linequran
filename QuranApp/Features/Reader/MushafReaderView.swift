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
                    ScrollView(.vertical, showsIndicators: false) {
                        MushafPageView(
                            pageNumber: pageNum,
                            lines: viewModel.pageLinesCache[pageNum] ?? [],
                            surahName: viewModel.currentSurahName,
                            juzNumber: viewModel.currentJuzNumber
                        )
                        .padding(.top, viewModel.isChromeVisible ? 60 : 16)
                        .padding(.bottom, viewModel.isChromeVisible ? 90 : 20)
                    }
                    .tag(pageNum)
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

            // Bottom Audio & Scrubbing Chrome
            if viewModel.isChromeVisible {
                VStack {
                    Spacer()
                    bottomChromeBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            await viewModel.onAppear()
        }
        .sheet(isPresented: $viewModel.isTranslationSheetPresented) {
            translationSheet
                .presentationDetents([.fraction(0.38), .medium, .large])
                .presentationDragIndicator(.visible)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.paperAged.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 12)
    }

    // MARK: - Bottom Chrome Bar (Audio & Page Scrubber)
    private var bottomChromeBar: some View {
        VStack(spacing: 8) {
            // Page Slider
            HStack(spacing: 12) {
                Text("1")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentPage) },
                        set: { viewModel.jumpToPage(Int($0)) }
                    ),
                    in: 1...849,
                    step: 1
                )
                .tint(AppColors.saddleAmber)

                Text("849")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)
            }
            .padding(.horizontal, 16)

            // Reciter & Audio Controls
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sheikh Khalifa Al Tunaiji")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.inkUmber)
                    Text("Hafs an Asim • Streaming CDN")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.sepiaMuted)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.inkUmber)
                }

                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(AppColors.saddleAmber)
                }
                .padding(.horizontal, 8)

                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.inkUmber)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.paperAged.opacity(0.95))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: -2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Translation Bottom Sheet
    private var translationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let ayah = viewModel.selectedAyah {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surah \(ayah.surahId) : Ayah \(ayah.verseNumber)")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.inkUmber)
                        Text("Page \(ayah.pageNumber) • Juz \(ayah.juzNumber)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.sepiaMuted)
                    }
                    Spacer()
                    Text(viewModel.selectedTranslationAuthor.displayName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.saddleAmber)
                }
                .padding(.top, 16)

                Divider()
                    .overlay(AppColors.borderSepia)

                // Arabic Verse
                Text(ayah.textIndopak)
                    .font(AppTypography.arabic13Line)
                    .foregroundStyle(AppColors.inkUmber)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.vertical, 4)

                // Translation Text
                if let trans = viewModel.activeAyahTranslation {
                    Text(trans.text)
                        .font(AppTypography.englishTranslation)
                        .foregroundStyle(AppColors.inkUmber)
                        .lineSpacing(4)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .background(AppColors.paperAged)
    }
}
