//
//  MushafLowerPanelDecoration.swift
//  QuranApp
//
//  Authentic vector geometric illumination panel that fills lines 9–13 on
//  frontispiece pages (Pages 1 and 2), preventing empty white slots and recreating
//  the illuminated manuscript carpet border found in physical 13-line codices.
//  Thread-safe and strictly compliant with Swift 6 concurrency.
//

import SwiftUI

public struct MushafLowerPanelDecoration: View {
    public let palette: ThemePalette

    public init(palette: ThemePalette = AppColors.palette(for: .sepia)) {
        self.palette = palette
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Subtle vellum tint
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.surfacePapyrus.opacity(0.6))

                // Outer border
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(palette.borderSepia.opacity(0.8), lineWidth: 0.75)

                // Inner fine border
                RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(palette.saddleAmber.opacity(0.4), lineWidth: 0.5)
                    .padding(3)

                // Islamic Geometric Rosette Pattern
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    guard w > 20, h > 20 else { return }

                    let strokeColor = Color(palette.borderSepia.opacity(0.35))
                    let accentColor = Color(palette.saddleAmber.opacity(0.35))

                    // Draw diagonal cross-hatch lattice
                    let step: CGFloat = 16
                    var x: CGFloat = step
                    while x < w {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 4))
                        path.addLine(to: CGPoint(x: max(4, x - h + 8), y: h - 4))
                        context.stroke(path, with: .color(strokeColor), lineWidth: 0.5)

                        var path2 = Path()
                        path2.move(to: CGPoint(x: x, y: 4))
                        path2.addLine(to: CGPoint(x: min(w - 4, x + h - 8), y: h - 4))
                        context.stroke(path2, with: .color(strokeColor), lineWidth: 0.5)

                        x += step
                    }

                    // Center Medallion
                    let center = CGPoint(x: w / 2, y: h / 2)
                    let radius: CGFloat = min(22, h * 0.28)
                    var circlePath = Path()
                    circlePath.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(circlePath, with: .color(accentColor), lineWidth: 0.75)

                    // Inner 8-point star in medallion
                    let starRadius = radius * 0.7
                    var starPath = Path()
                    for i in 0..<8 {
                        let angle = Double(i) * Double.pi / 4.0
                        let r = (i % 2 == 0) ? starRadius : starRadius * 0.5
                        let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
                        if i == 0 { starPath.move(to: pt) } else { starPath.addLine(to: pt) }
                    }
                    starPath.closeSubpath()
                    context.stroke(starPath, with: .color(accentColor), lineWidth: 0.75)
                }
                .padding(4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
