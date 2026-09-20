//
//  QuranApp.swift
//  QuranApp
//
//  Main application entry point for the 13-Line Quran Reader.
//  Targeting iOS 17.0+ and Swift 6 concurrency.
//

import SwiftUI

@main
struct ThirteenLineQuranApp: App {
    @State private var databaseService: QuranDatabaseService?
    @State private var userDatabaseService: UserDatabaseService?
    @State private var downloadManager: DownloadManager?
    @State private var themeManager = ThemeManager()
    @State private var initialPage: Int = 1
    @State private var initError: String?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

    /// Diagnostic hooks used only by automated UI tests and CI screenshot
    /// capture. Absent arguments leave production behaviour completely
    /// unchanged: no default page override and the normal onboarding flow.
    private static let isAutomatedRun = CommandLine.arguments.contains("-mushafAutomatedRun")

    private static var requestedInitialPage: Int? {
        guard isAutomatedRun,
              let index = CommandLine.arguments.firstIndex(of: "-mushafInitialPage"),
              CommandLine.arguments.indices.contains(index + 1),
              let page = Int(CommandLine.arguments[index + 1]),
              (1...849).contains(page) else { return nil }
        return page
    }

    init() {
        // Register custom IndoPak Nastaleeq font if needed at launch
        registerCustomFonts()
        if let page = Self.requestedInitialPage {
            _initialPage = State(initialValue: page)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let service = databaseService, let userDb = userDatabaseService, let dm = downloadManager {
                    RootTabView(
                        repository: service,
                        userDatabase: userDb,
                        downloadManager: dm,
                        themeManager: themeManager,
                        initialPage: initialPage
                    )
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView(themeManager: themeManager) {
                            showOnboarding = false
                        }
                    }
                } else if let error = initError {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text("Database Initialization Error")
                            .font(AppTypography.headline)
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.sepiaMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.paperAged)
                } else {
                    // Launching / Splash
                    VStack(spacing: 16) {
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(AppColors.saddleAmber)
                        ProgressView()
                            .tint(AppColors.saddleAmber)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.paperAged)
                }
            }
            .task {
                do {
                    let quranService = try QuranDatabaseService()
                    let userDb = try UserDatabaseService()
                    let lastRead = try await userDb.getLastReadPage()
                    let dm = DownloadManager(repository: quranService)

                    self.databaseService = quranService
                    self.userDatabaseService = userDb
                    self.downloadManager = dm
                    if let requested = Self.requestedInitialPage {
                        self.initialPage = requested
                    } else {
                        self.initialPage = lastRead
                    }

                    if !hasCompletedOnboarding, !Self.isAutomatedRun {
                        self.showOnboarding = true
                    }
                } catch {
                    self.initError = error.localizedDescription
                }
            }
        }
    }

    private func registerCustomFonts() {
        guard let fontURL = Bundle.main.url(forResource: "IndoPak-Nastaleeq", withExtension: "ttf") else {
            return
        }
        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }
}
