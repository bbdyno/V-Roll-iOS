//
//  PrimaryActionButton.swift
//  Feature
//
//  Headline call-to-action used on every screen. Filled with the brand
//  gradient when prominent, ghost-styled otherwise. The press effect
//  uses a snappy spring rather than the default opacity dimming because
//  on a near-black surface the system dim is barely visible.
//

import SwiftUI
import Core

public struct PrimaryActionButton: View {
    public enum Style {
        case filled
        case ghost
    }

    public let title: String
    public let systemImage: String?
    public let style: Style
    public let isLoading: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .filled,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: VRollTheme.Spacing.s) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))
            .overlay {
                if style == .ghost {
                    RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous)
                        .stroke(VRollTheme.divider, lineWidth: 1)
                }
            }
            .shadow(
                color: style == .filled ? VRollTheme.accent.opacity(0.35) : .clear,
                radius: 18,
                y: 8
            )
        }
        .buttonStyle(PressableScaleStyle())
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .ghost: return VRollTheme.textPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            VRollTheme.accentGradient
        case .ghost:
            VRollTheme.surface
        }
    }
}

private struct PressableScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(VRollTheme.Motion.snappy, value: configuration.isPressed)
    }
}
