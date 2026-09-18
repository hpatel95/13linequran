//
//  OnboardingView.swift
//  QuranApp
//
//  Serene, 3-step 15-second first-launch onboarding flow allowing
//  users to personalize their reading theme, translation, and start reciting.
//

import SwiftUI

public struct OnboardingView: View {
    public let themeManager: ThemeManager
    public let onFinish: (() -> Void)?

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("selectedTranslation") private var selectedTranslation: String = "saheeh"
    @State private var currentPageIndex: Int = 0

    public init(themeManager: ThemeManager, onFinish: (() -> Void)? = nil) {
        self.themeManager = themeManager
        self.onFinish = onFinish
    }

    private var palette: ThemePalette {
        themeManager.colors
    }

    public var body: some View {
        ZStack {
            palette.canvasVellum.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Skip button
                HStack {
                    Spacer()
                    if currentPageIndex < 2 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.sepiaMuted)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }

                TabView(selection: $currentPageIndex) {
                    welcomeStep.tag(0)
                    personalizeStep.tag(1)
                    readyStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: currentPageIndex)

                // Bottom Navigation Bar
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }

    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon / Emblem
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(palette.surfacePapyrus)
                        .frame(width: 90, height: 90)
                        .overlay(Circle().stroke(palette.borderSepia, lineWidth: 1))

                    Text("❖")
                        .font(.system(size: 40))
                        .foregroundStyle(palette.saddleAmber)
                }

                Text("13-Line Quran")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(palette.inkUmber)

                Text("The Traditional Indo-Pak Lithograph")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.saddleAmber)
            }

            // Description Box
            VStack(spacing: 12) {
                Text("Rendered directly in the classical 13-line format used across South Asia, Turkey, and worldwide. 849 pages of verified calligraphic text with instant ayah lookup.")
                    .font(AppTypography.bodyEnglish)
                    .foregroundStyle(palette.sepiaMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                // Sadaqah Jariyah Badge
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.saddleAmber)

                    Text("100% Free • No Ads • Zero Subscriptions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.saddleAmber)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(palette.surfacePapyrus)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(palette.borderSepia, lineWidth: 0.5))
            }

            Spacer()
        }
    }

    // MARK: - Step 2: Personalize
    private var personalizeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 6) {
                Text("Personalize Your Mushaf")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(palette.inkUmber)

                Text("Select your reading palette and primary translation")
                    .font(AppTypography.caption)
                    .foregroundStyle(palette.sepiaMuted)
            }

            // Theme Cards
            VStack(spacing: 10) {
                ForEach(AppTheme.allCases) { theme in
                    let isSelected = themeManager.currentTheme == theme
                    let themePal = AppColors.palette(for: theme)

                    Button(action: {
                        themeManager.setTheme(theme)
                    }) {
                        HStack(spacing: 14) {
                            // Swatch Preview
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(themePal.paperAged)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themePal.borderSepia, lineWidth: 1)
                                    )

                                Text("ق")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundStyle(themePal.inkUmber)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(theme.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.inkUmber)

                                Text(theme.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(palette.sepiaMuted)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(palette.saddleAmber)
                            } else {
                                Circle()
                                    .stroke(palette.borderSepia, lineWidth: 1.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                        .padding(12)
                        .background(palette.paperAged)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? palette.saddleAmber : palette.borderSepia, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)

            // Translation Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("TRANSLATION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.sepiaMuted)
                    .padding(.leading, 24)

                VStack(spacing: 4) {
                    translationButton(title: "Saheeh International (English)", tag: "saheeh")
                    translationButton(title: "Dr. Hilali & Dr. Muhsin Khan (English)", tag: "hilali_khan")
                    translationButton(title: "Dr. Muhammad Hamidullah (Français)", tag: "hamidullah")
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    private func translationButton(title: String, tag: String) -> some View {
        let isSelected = selectedTranslation == tag
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                selectedTranslation = tag
            }
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(palette.inkUmber)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.saddleAmber)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(palette.paperAged)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? palette.saddleAmber : palette.borderSepia, lineWidth: isSelected ? 1 : 0.5))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Step 3: Ready
    private var readyStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Calligraphy
            Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                .font(.system(size: 28, design: .serif))
                .foregroundStyle(palette.saddleAmber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Text("Begin Your Recitation")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(palette.inkUmber)

                Text("May Allah make the Holy Quran the spring of our hearts, the light of our chests, and the banisher of our sorrows.")
                    .font(AppTypography.bodyEnglish)
                    .foregroundStyle(palette.sepiaMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
            }

            // Quick feature summary
            VStack(spacing: 12) {
                featureRow(icon: "waveform", title: "Offline Recitation", desc: "Listen to Sheikh Khalifa Al Tunaiji anytime")
                featureRow(icon: "magnifyingglass", title: "FTS5 Instant Search", desc: "Search across Arabic, Surah titles & translations")
                featureRow(icon: "bookmark.fill", title: "Personal Bookmarks", desc: "Save pages and individual ayahs with one tap")
            }
            .padding(16)
            .background(palette.surfacePapyrus.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.borderSepia, lineWidth: 1))
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(palette.saddleAmber)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.inkUmber)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.sepiaMuted)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Page Indicator Dots
            HStack(spacing: 6) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(currentPageIndex == idx ? palette.saddleAmber : palette.borderSepia)
                        .frame(width: currentPageIndex == idx ? 8 : 6, height: currentPageIndex == idx ? 8 : 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentPageIndex)
                }
            }

            // Action Button (50pt height for accessible touch target)
            Button(action: {
                if currentPageIndex < 2 {
                    withAnimation {
                        currentPageIndex += 1
                    }
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } else {
                    completeOnboarding()
                }
            }) {
                Text(currentPageIndex == 2 ? "Start Reading" : "Continue")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(palette.saddleAmber)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: palette.saddleAmber.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(currentPageIndex == 2 ? "Start reading Surah Al-Fatihah" : "Continue to next onboarding step")
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        onFinish?()
    }
}
