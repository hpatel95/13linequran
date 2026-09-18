//
//  PageJumpView.swift
//  QuranApp
//
//  Direct page navigation view enabling quick jump to any 13-line Mushaf page (1–849)
//  via direct numeric input or 30-Juz rapid milestone jumping.
//

import SwiftUI

public struct PageJumpView: View {
    public let juzs: [Juz]
    public let onSelectPage: (Int) -> Void

    @State private var inputPageText: String = ""
    @State private var inputErrorMessage: String?

    public init(juzs: [Juz], onSelectPage: @escaping (Int) -> Void) {
        self.juzs = juzs
        self.onSelectPage = onSelectPage
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // MARK: - Direct Numeric Entry Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("Direct Page Jump")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(AppColors.inkUmber)

                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "book.pages")
                                .foregroundStyle(AppColors.sepiaMuted)
                            TextField("Enter page (1–849)", text: $inputPageText)
                                .font(AppTypography.body)
                                .keyboardType(.numberPad)
                                .foregroundStyle(AppColors.inkUmber)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.surfacePapyrus.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.borderSepia, lineWidth: 1))

                        Button(action: jumpToInputPage) {
                            Text("Go")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 54, minHeight: 44)
                                .background(AppColors.saddleAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if let error = inputErrorMessage {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.paperAged.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                )
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.borderSepia, lineWidth: 1))

                // MARK: - 30 Juz Milestone Quick Grid
                VStack(alignment: .leading, spacing: 12) {
                    Text("Juz Starting Pages")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(AppColors.inkUmber)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                        ForEach(juzs) { juz in
                            Button(action: {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                onSelectPage(juz.startPage)
                            }) {
                                VStack(spacing: 3) {
                                    Text("Juz \(juz.id)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.inkUmber)
                                    Text("p. \(juz.startPage)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(AppColors.saddleAmber)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .padding(.vertical, 6)
                                .background(AppColors.paperAged)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.borderSepia, lineWidth: 1))
                            }
                            .buttonStyle(IndexRowButtonStyle())
                            .accessibilityLabel("Juz \(juz.id), Page \(juz.startPage)")
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.paperAged.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
                )
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.borderSepia, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 24)
        }
    }

    private func jumpToInputPage() {
        guard let page = Int(inputPageText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            inputErrorMessage = "Please enter a valid page number"
            return
        }

        if page >= 1 && page <= 849 {
            inputErrorMessage = nil
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onSelectPage(page)
        } else {
            inputErrorMessage = "Page must be between 1 and 849"
        }
    }
}
