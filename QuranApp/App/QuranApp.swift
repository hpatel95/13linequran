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
    @State private var initialPage: Int = 1
    @State private var initError: String?

    init() {
        // Register custom IndoPak Nastaleeq font if needed at launch
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let service = databaseService, let userDb = userDatabaseService {
                    RootTabView(
                        repository: service,
                        userDatabase: userDb,
                        initialPage: initialPage
                    )
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
                    let lastRead = await userDb.getLastReadPage()

                    self.databaseService = quranService
                    self.userDatabaseService = userDb
                    self.initialPage = lastRead
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
