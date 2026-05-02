//
//  EmptyStateView.swift
//  Feature
//
//  Hero placeholder shown on the home screen before the user has
//  imported any clips. The icon "breathes" with a continuous, slow
//  scale animation — keeps the screen feeling alive without being
//  distracting.
//

import SwiftUI
import Core

public struct EmptyStateView: View {
    public let systemImage: String
    public let title: String
    public let subtitle: String

    @State private var pulse = false

    public init(systemImage: String, title: String, subtitle: String) {
        self.systemImage = systemImage
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: VRollTheme.Spacing.l) {
            ZStack {
                Circle()
                    .fill(VRollTheme.accent.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.05 : 0.95)
                Circle()
                    .strokeBorder(VRollTheme.accent.opacity(0.25), lineWidth: 1)
                    .frame(width: 168, height: 168)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .opacity(pulse ? 0.4 : 0.9)
                Image(systemName: systemImage)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(VRollTheme.accentGradient)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }

            VStack(spacing: VRollTheme.Spacing.s) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VRollTheme.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VRollTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
    }
}
