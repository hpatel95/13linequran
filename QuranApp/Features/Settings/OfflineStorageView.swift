//
//  OfflineStorageView.swift
//  QuranApp
//
//  Stitch-accurate offline audio storage manager displaying disk footprint,
//  per-Surah download progress, swipe-to-delete, and cache clearing.
//

import SwiftUI

public struct OfflineStorageView: View {
    @Bindable public var downloadManager: DownloadManager
    @State private var searchText: String = ""
    @State private var selectedFilter: FilterMode = .all
    @State private var showClearConfirmation: Bool = false

    public enum FilterMode: String, CaseIterable {
        case all = "All"
        case downloaded = "Downloaded"
    }

    public init(downloadManager: DownloadManager) {
        self.downloadManager = downloadManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Storage Overview Card
            storageOverviewCard
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            // MARK: - Filter & Search Controls
            filterAndSearchBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider().overlay(AppColors.borderSepia)

            // MARK: - Surah Download List
            surahList
        }
        .background(AppColors.canvasVellum.ignoresSafeArea())
        .navigationTitle("Offline Audio Recitation")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await downloadManager.loadAndScan()
        }
        .alert("Clear All Audio Cache?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                downloadManager.clearAllAudioCache()
            }
        } message: {
            Text("This will delete all downloaded recitation files from your device. You can download them again anytime.")
        }
    }

    // MARK: - Storage Overview Card
    private var storageOverviewCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sheikh Khalifa Al Tunaiji (64kbps)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.saddleAmber)

                    Text(downloadManager.formattedStorageSize())
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(AppColors.inkUmber)

                    Text("\(downloadManager.downloadedSurahsCount) of \(downloadManager.surahs.count) Surahs downloaded")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.sepiaMuted)
                }

                Spacer()

                if downloadManager.totalStorageUsedBytes > 0 {
                    Button(action: { showClearConfirmation = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Clear")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Clear all downloaded audio cache")
                }
            }

            // Progress bar showing fraction of 114 Surahs downloaded
            let fraction = Double(downloadManager.downloadedSurahsCount) / Double(max(1, downloadManager.surahs.count))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.borderSepia.opacity(0.5))
                        .frame(height: 6)

                    Capsule()
                        .fill(AppColors.saddleAmber)
                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.paperAged)
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.borderSepia, lineWidth: 1)
        )
    }

    // MARK: - Filter and Search Bar
    private var filterAndSearchBar: some View {
        VStack(spacing: 8) {
            // Filter Pills
            HStack(spacing: 8) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    let isSelected = selectedFilter == mode
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            selectedFilter = mode
                        }
                    }) {
                        Text(mode == .all ? "All (114)" : "Downloaded (\(downloadManager.downloadedSurahsCount))")
                            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : AppColors.sepiaMuted)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(isSelected ? AppColors.saddleAmber : AppColors.surfacePapyrus.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(isSelected ? AppColors.saddleAmber : AppColors.borderSepia, lineWidth: 0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.sepiaMuted)

                TextField("Search Surah by name or number...", text: $searchText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.inkUmber)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.sepiaMuted)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(AppColors.surfacePapyrus)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.borderSepia, lineWidth: 0.5))
        }
    }

    // MARK: - Surah List
    private var surahList: some View {
        List {
            ForEach(filteredSurahs) { surah in
                surahDownloadRow(surah)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if downloadManager.status(for: surah.id).isDownloaded {
                            Button(role: .destructive) {
                                downloadManager.deleteSurahDownload(surah)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.top, 4)
    }

    // MARK: - Single Surah Row
    private func surahDownloadRow(_ surah: Surah) -> some View {
        let status = downloadManager.status(for: surah.id)

        return HStack(spacing: 12) {
            // Surah Number Badge
            Text("\(surah.id)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.sepiaMuted)
                .frame(width: 32, height: 32)
                .background(AppColors.surfacePapyrus)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.borderSepia, lineWidth: 0.5))

            // Surah Metadata
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(surah.englishName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.inkUmber)

                    Text(surah.arabicName)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(AppColors.saddleAmber)
                }

                Text("\(surah.totalVerses) Verses • p. \(surah.startPage)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.sepiaMuted)
            }

            Spacer()

            // Download Action Controls (44x44pt target)
            downloadActionButton(surah: surah, status: status)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.paperAged.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(status.isDownloaded ? AppColors.saddleAmber.opacity(0.4) : AppColors.borderSepia, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func downloadActionButton(surah: Surah, status: DownloadStatus) -> some View {
        switch status {
        case .notDownloaded:
            Button(action: {
                downloadManager.downloadSurah(surah)
            }) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.saddleAmber)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Download \(surah.englishName)")

        case .downloading(let progress):
            Button(action: {
                downloadManager.cancelDownload(surahId: surah.id)
            }) {
                ZStack {
                    ProgressView(value: progress)
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.saddleAmber))
                        .frame(width: 24, height: 24)

                    Image(systemName: "stop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(AppColors.saddleAmber)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Cancel download for \(surah.englishName), \(Int(progress * 100)) percent complete")

        case .downloaded:
            Menu {
                Button(role: .destructive) {
                    downloadManager.deleteSurahDownload(surah)
                } label: {
                    Label("Delete Download", systemImage: "trash")
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.green)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(surah.englishName) is downloaded. Tap for options.")

        case .failed(let message):
            Button(action: {
                downloadManager.downloadSurah(surah)
            }) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Download failed: \(message). Tap to retry.")
        }
    }

    // MARK: - Filtered Surahs
    private var filteredSurahs: [Surah] {
        var list = downloadManager.surahs

        if selectedFilter == .downloaded {
            list = list.filter { downloadManager.status(for: $0.id).isDownloaded }
        }

        if !searchText.isEmpty {
            list = list.filter {
                $0.englishName.localizedCaseInsensitiveContains(searchText) ||
                $0.arabicName.contains(searchText) ||
                String($0.id).contains(searchText)
            }
        }

        return list
    }
}
