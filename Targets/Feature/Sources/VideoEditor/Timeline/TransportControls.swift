//
//  TransportControls.swift
//  Feature
//
//  Compact play/pause + time readout. Time labels use `.fixedSize` so
//  the capsule hugs the actual digit width — the previous version
//  reserved 64pt per label, which combined with surrounding inspector
//  buttons pushed the whole row past the screen edge on iPhone-class
//  devices.
//

import SwiftUI
import AVFoundation
import CoreMedia
import Core

struct TransportControls: View {
    @Bindable var preview: VideoPreviewEngine

    var body: some View {
        HStack(spacing: VRollTheme.Spacing.s) {
            timeText(preview.currentTime, color: VRollTheme.textPrimary)
            playPauseButton
            timeText(preview.duration, color: VRollTheme.textSecondary)
        }
        .padding(.horizontal, VRollTheme.Spacing.m)
        .padding(.vertical, VRollTheme.Spacing.xs)
        .background(VRollTheme.surface, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var playPauseButton: some View {
        Button {
            withAnimation(VRollTheme.Motion.snappy) {
                preview.togglePlayback()
            }
        } label: {
            Image(systemName: preview.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(VRollTheme.accentGradient)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: VRollTheme.accent.opacity(0.4), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func timeText(_ time: CMTime, color: Color) -> some View {
        Text(format(time))
            .font(.caption.monospacedDigit())
            .foregroundStyle(color)
            .fixedSize()
    }

    private func format(_ time: CMTime) -> String {
        let total = max(0, CMTimeGetSeconds(time))
        guard total.isFinite else { return "00:00.00" }
        let minutes = Int(total) / 60
        let seconds = Int(total) % 60
        let centi = Int((total - floor(total)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centi)
    }
}
