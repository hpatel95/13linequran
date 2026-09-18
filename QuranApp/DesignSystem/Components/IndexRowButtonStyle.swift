//
//  IndexRowButtonStyle.swift
//  QuranApp
//
//  Apple fluid motion button style providing instant touch-down scale effect (0.97)
//  with spring physics and light tactile feedback.
//

import SwiftUI

public struct IndexRowButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 1.0), value: configuration.isPressed)
    }
}
