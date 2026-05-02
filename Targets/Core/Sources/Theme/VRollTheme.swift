//
//  VRollTheme.swift
//  Core
//
//  Black-first design tokens. Surfaces step *up* in lightness as
//  elevation increases — that's the inversion of the iOS default
//  "elevated grays get whiter" idea, which collapses to mud on OLED.
//  Each step is ~4% in luminance so the hierarchy reads even with the
//  whole UI rendered on top of `background`.
//

import SwiftUI

public enum VRollTheme {
    // MARK: - Surfaces

    public static let background = Color(red: 0.04, green: 0.04, blue: 0.05)
    public static let surface = Color(red: 0.10, green: 0.10, blue: 0.12)
    public static let surfaceElevated = Color(red: 0.14, green: 0.14, blue: 0.17)
    public static let divider = Color.white.opacity(0.08)

    // MARK: - Text

    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.40)

    // Back-compat aliases — keep until call sites migrate.
    public static let onSurface = textPrimary
    public static let muted = textSecondary

    // MARK: - Accent

    public static let accent = Color(red: 0.937, green: 0.282, blue: 0.984)
    public static let accentSecondary = Color(red: 0.482, green: 0.345, blue: 0.992)

    public static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Layout

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 16
        public static let l: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum Radius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let pill: CGFloat = 999
    }

    public enum Motion {
        public static let snappy = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.78)
        public static let soft = SwiftUI.Animation.spring(response: 0.55, dampingFraction: 0.85)
        public static let fade = SwiftUI.Animation.easeInOut(duration: 0.22)
    }
}
