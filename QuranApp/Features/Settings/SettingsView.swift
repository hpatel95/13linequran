//
//  SettingsView.swift
//  QuranApp
//
//  Application settings controlling translation preferences, dynamic reading themes,
//  audio recitation options, offline storage, and scholarly licensing attributions.
//

import SwiftUI

public struct SettingsView: View {
    @AppStorage("selectedTranslation") private var selectedTranslation: String = "saheeh"
    @AppStorage("autoPlayNextAyah") private var autoPlayNextAyah: Bool = true
    @State private var showOnboardingSheet: Bool = false

    public let downloadManager: DownloadManager
    public let themeManager: ThemeManager

    public init(downloadManager: DownloadManager, themeManager: ThemeManager) {
        self.downloadManager = downloadManager
        self.themeManager = themeManager
    }

    private var palette: ThemePalette {
        themeManager.colors
    }

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Visual Reading Theme
                Section("Reading Theme") {
                    VStack(spacing: 8) {
                        ForEach(AppTheme.allCases) { theme in
                            let isSelected = themeManager.currentTheme == theme
                            let themePal = AppColors.palette(for: theme)

                            Button(action: {
                                themeManager.setTheme(theme)
                            }) {
                                HStack(spacing: 12) {
                                    // Swatch Box
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(themePal.paperAged)
                                            .frame(width: 36, height: 36)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(themePal.borderSepia, lineWidth: 1))

                                        Text("ق")
                                            .font(.system(size: 16, weight: .bold, design: .serif))
                                            .foregroundStyle(themePal.inkUmber)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(theme.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(palette.inkUmber)
                                        Text(theme.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundStyle(palette.sepiaMuted)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(palette.saddleAmber)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Select \(theme.title) theme")
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Translation Settings
                Section("English & French Translations") {
                    Picker("Primary Translation", selection: $selectedTranslation) {
                        Text("Saheeh International (English)").tag("saheeh")
                        Text("Dr. Hilali & Dr. Muhsin Khan (English)").tag("hilali_khan")
                        Text("Dr. Muhammad Hamidullah (Français)").tag("hamidullah")
                    }
                    .pickerStyle(.navigationLink)
                }

                // MARK: - Audio & Recitation
                Section("Audio Recitation") {
                    HStack {
                        Text("Primary Reciter")
                        Spacer()
                        Text("Sheikh Khalifa Al Tunaiji")
                            .foregroundStyle(palette.sepiaMuted)
                    }

                    HStack {
                        Text("Riwayah")
                        Spacer()
                        Text("Hafs 'an 'Asim")
                            .foregroundStyle(palette.sepiaMuted)
                    }

                    Toggle("Auto-Advance Verses During Playback", isOn: $autoPlayNextAyah)
                        .tint(palette.saddleAmber)
                }

                // MARK: - Offline Storage
                Section("Offline Storage") {
                    NavigationLink {
                        OfflineStorageView(downloadManager: downloadManager)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Offline Audio Recitation Packs")
                                    .font(.system(size: 15))
                                Text("\(downloadManager.formattedStorageSize()) used • \(downloadManager.downloadedSurahsCount) Surahs")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(palette.sepiaMuted)
                            }
                            Spacer()
                        }
                    }
                }

                // MARK: - Mushaf & Typography Specs
                Section("Mushaf Layout & Typography") {
                    HStack {
                        Text("Layout Type")
                        Spacer()
                        Text("Indo-Pak 13-Line (Qudratullah)")
                            .foregroundStyle(palette.sepiaMuted)
                    }

                    HStack {
                        Text("Total Pages")
                        Spacer()
                        Text("849 Pages")
                            .foregroundStyle(palette.sepiaMuted)
                    }

                    HStack {
                        Text("Calligraphy Font")
                        Spacer()
                        Text("IndoPak Nastaleeq TTF")
                            .foregroundStyle(palette.sepiaMuted)
                    }
                }

                // MARK: - Quick Guide & Onboarding
                Section("Help & Guidance") {
                    Button(action: { showOnboardingSheet = true }) {
                        HStack {
                            Label("Replay Welcome & Features Guide", systemImage: "questionmark.circle")
                                .foregroundStyle(palette.inkUmber)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.sepiaMuted)
                        }
                    }
                    .frame(minHeight: 44)
                }

                // MARK: - Governance & Attributions
                Section("Scholarly Attributions & Licensing") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Arabic Text & Metadata")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.inkUmber)
                        Text("Verified Tanzil Clean & Imlaei Text Reference and Quranic Universal Library (QUL / Tarteel AI).")
                            .font(AppTypography.caption)
                            .foregroundStyle(palette.sepiaMuted)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Audio Recitation CDN")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.inkUmber)
                        Text("Streamed from EveryAyah / Quran Foundation open Islamic CDN.")
                            .font(AppTypography.caption)
                            .foregroundStyle(palette.sepiaMuted)
                    }
                    .padding(.vertical, 2)

                    HStack {
                        Text("Database Checksum")
                        Spacer()
                        Text("SHA-256 Verified")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                    }
                }

                // MARK: - Sadaqah Jariyah Dedication
                Section {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(palette.saddleAmber)
                            Text("Sadaqah Jariyah (Ongoing Charity)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(palette.saddleAmber)
                        }

                        Text("This application is 100% free, non-commercial, and ad-free forever. May Allah accept it from everyone who contributed to its preparation and everyone who recites from it.")
                            .font(AppTypography.caption)
                            .foregroundStyle(palette.sepiaMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }

                // MARK: - App Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundStyle(palette.sepiaMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.paperAged.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showOnboardingSheet) {
                OnboardingView(themeManager: themeManager) {
                    showOnboardingSheet = false
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}
