//
//  CircularProgressRing.swift
//  Feature
//
//  Gradient progress ring used by the export screen. Built directly on
//  `Circle().trim(...).stroke(...)` so we get smooth interpolation as
//  the export progress closure fires every 100ms — `.animation` on the
//  trim is what makes the fill glide instead of step.
//

import SwiftUI
import Core

public struct CircularProgressRing: View {
    public let progress: Double
    public let lineWidth: CGFloat
    public let centerLabel: String?

    public init(progress: Double, lineWidth: CGFloat = 12, centerLabel: String? = nil) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.centerLabel = centerLabel
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(VRollTheme.surfaceElevated, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    VRollTheme.accentGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(VRollTheme.Motion.soft, value: progress)
                .shadow(color: VRollTheme.accent.opacity(0.4), radius: 12)

            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(VRollTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(VRollTheme.Motion.snappy, value: progress)
                if let centerLabel {
                    Text(centerLabel)
                        .font(.caption)
                        .foregroundStyle(VRollTheme.textSecondary)
                }
            }
        }
        .padding(lineWidth)
    }
}
