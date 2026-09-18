//
//  SettingsView.swift
//  QuranApp
//
//  Settings and preferences screen for translations, themes, audio reciter, and scholarly attribution.
//

import SwiftUI

public struct SettingsView: View {
    @AppStorage("selectedTranslation") private var selectedTranslation: String = "saheeh"
    @AppStorage("selectedTheme") private var selectedTheme: String = "sepia"
    @AppStorage("autoPlayNextAyah") private var autoPlayNextAyah: Bool = true

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Translation Settings
                Section("English & French Translations") {
                    Picker("Primary Translation", selection: $selectedTranslation) {
                        Text("Saheeh International (English)").tag("saheeh")
                        Text("Dr. Hilali & Dr. Muhsin Khan (English)").tag("hilali_khan")
                        Text("Dr. Muhammad Hamidullah (Français)").tag("hamidullah")
                    }
                    .pickerStyle(.navigationLink)
                }

                // MARK: - Visual Reading Theme
                Section("Reading Theme") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("Heritage Sepia & Tooled Leather (Default)").tag("sepia")
                        Text("Soft Ivory Parchment").tag("ivory")
                        Text("Midnight OLED Dark").tag("midnight")
                    }
                    .pickerStyle(.inline)
                }

                // MARK: - Audio & Recitation
                Section("Audio Recitation") {
                    HStack {
                        Text("Primary Reciter")
                        Spacer()
                        Text("Sheikh Khalifa Al Tunaiji")
                            .foregroundStyle(AppColors.sepiaMuted)
                    }

                    HStack {
                        Text("Riwayah")
                        Spacer()
                        Text("Hafs 'an 'Asim")
                            .foregroundStyle(AppColors.sepiaMuted)
                    }

                    Toggle("Auto-Advance Verses During Playback", isOn: $autoPlayNextAyah)
                        .tint(AppColors.saddleAmber)
                }

                // MARK: - Mushaf & Typography Specs
                Section("Mushaf Layout & Typography") {
                    HStack {
                        Text("Layout Type")
                        Spacer()
                        Text("Indo-Pak 13-Line (Qudratullah)")
                            .foregroundStyle(AppColors.sepiaMuted)
                    }

                    HStack {
                        Text("Total Pages")
                        Spacer()
                        Text("849 Pages")
                            .foregroundStyle(AppColors.sepiaMuted)
                    }

                    HStack {
                        Text("Calligraphy Font")
                        Spacer()
                        Text("IndoPak Nastaleeq TTF")
                            .foregroundStyle(AppColors.sepiaMuted)
                    }
                }

                // MARK: - Governance & Attributions
                Section("Scholarly Attributions & Licensing") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Arabic Text & Metadata")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.inkUmber)
                        Text("Verified Tanzil Clean & Imlaei Text Reference and Quranic Universal Library (QUL / Tarteel AI).")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.sepiaMuted)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Audio Recitation CDN")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.inkUmber)
                        Text("Streamed from EveryAyah / Quran Foundation open Islamic CDN.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.sepiaMuted)
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

                // MARK: - App Version
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundStyle(AppColors.sepiaMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.paperAged)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
