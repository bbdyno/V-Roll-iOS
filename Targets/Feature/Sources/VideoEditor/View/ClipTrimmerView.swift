//
//  ClipTrimmerView.swift
//  Feature
//
//  Per-clip trim editor. Built around an `AVPlayer` whose
//  `forwardPlaybackEndTime` is pinned to the trim out-point — when
//  AVPlayer reaches the end-time it raises
//  `AVPlayerItemDidPlayToEndTime`, at which point we seek back to the
//  trim in-point. That gives us a tight, gap-free loop preview without
//  having to drive a CADisplayLink ourselves.
//
//  The dual-handle range slider underneath the player is custom (not
//  `Slider`, since SwiftUI's `Slider` only takes one value) and reports
//  the selection back as a `CMTimeRange`.
//

import SwiftUI
import AVKit
import AVFoundation
import CoreMedia
import Combine
import Core

public struct ClipTrimmerView: View {
    public let clip: VideoClip
    public let onSave: (CMTimeRange) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var player = AVPlayer()
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var isScrubbing = false
    @State private var endObserver: NSObjectProtocol?

    private var totalSeconds: Double {
        max(0.05, CMTimeGetSeconds(clip.duration))
    }

    public init(clip: VideoClip, onSave: @escaping (CMTimeRange) -> Void) {
        self.clip = clip
        self.onSave = onSave
    }

    public var body: some View {
        ZStack {
            VRollTheme.background.ignoresSafeArea()

            VStack(spacing: VRollTheme.Spacing.l) {
                playerSurface
                    .padding(.horizontal, VRollTheme.Spacing.m)

                trimSlider
                    .padding(.horizontal, VRollTheme.Spacing.l)

                statsRow
                    .padding(.horizontal, VRollTheme.Spacing.l)

                Spacer(minLength: 0)

                actionRow
                    .padding(.horizontal, VRollTheme.Spacing.l)
                    .padding(.bottom, VRollTheme.Spacing.m)
            }
        }
        .navigationTitle(FeatureStrings.Trim.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(VRollTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear(perform: configurePlayer)
        .onDisappear(perform: teardownPlayer)
        .onChange(of: trimStart) { _, _ in handleTrimChange(seekToStart: true) }
        .onChange(of: trimEnd) { _, _ in handleTrimChange(seekToStart: false) }
    }

    // MARK: - Player

    @ViewBuilder
    private var playerSurface: some View {
        VideoPlayer(player: player)
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous)
                    .stroke(VRollTheme.divider, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
    }

    private func configurePlayer() {
        let initial = clip.trimRange
        trimStart = max(0, CMTimeGetSeconds(initial.start))
        trimEnd = min(totalSeconds, trimStart + CMTimeGetSeconds(initial.duration))
        if trimEnd <= trimStart { trimEnd = totalSeconds }

        let item = AVPlayerItem(asset: AVURLAsset(url: clip.url))
        item.forwardPlaybackEndTime = CMTime(seconds: trimEnd, preferredTimescale: 600)
        player.replaceCurrentItem(with: item)
        player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
            player.play()
        }

        player.play()
    }

    private func teardownPlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func handleTrimChange(seekToStart: Bool) {
        guard let item = player.currentItem else { return }
        item.forwardPlaybackEndTime = CMTime(seconds: trimEnd, preferredTimescale: 600)
        if seekToStart || isScrubbing {
            let target = seekToStart ? trimStart : max(trimStart, trimEnd - 0.5)
            player.seek(
                to: CMTime(seconds: target, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
        }
    }

    // MARK: - Slider

    @ViewBuilder
    private var trimSlider: some View {
        TrimRangeSlider(
            startSeconds: $trimStart,
            endSeconds: $trimEnd,
            totalSeconds: totalSeconds,
            isScrubbing: $isScrubbing
        )
        .frame(height: 64)
    }

    @ViewBuilder
    private var statsRow: some View {
        HStack {
            stat(label: FeatureStrings.Trim.start, value: trimStart)
            Spacer()
            stat(label: FeatureStrings.Trim.length, value: trimEnd - trimStart, accent: true)
            Spacer()
            stat(label: FeatureStrings.Trim.end, value: trimEnd)
        }
    }

    @ViewBuilder
    private func stat(label: String, value: Double, accent: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(VRollTheme.textTertiary)
            Text(String(format: "%.2fs", value))
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(accent ? VRollTheme.accent : VRollTheme.textPrimary)
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: VRollTheme.Spacing.s) {
            PrimaryActionButton(
                FeatureStrings.Common.close,
                style: .ghost
            ) {
                dismiss()
            }
            PrimaryActionButton(
                FeatureStrings.Trim.save,
                systemImage: "checkmark.circle.fill",
                style: .filled
            ) {
                let range = CMTimeRange(
                    start: CMTime(seconds: trimStart, preferredTimescale: 600),
                    duration: CMTime(seconds: max(0.05, trimEnd - trimStart), preferredTimescale: 600)
                )
                onSave(range)
                dismiss()
            }
        }
    }
}

// MARK: - Range slider

private struct TrimRangeSlider: View {
    @Binding var startSeconds: Double
    @Binding var endSeconds: Double
    let totalSeconds: Double
    @Binding var isScrubbing: Bool

    private let handleWidth: CGFloat = 14
    private let trackHeight: CGFloat = 56

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let startX = position(forSeconds: startSeconds, in: width)
            let endX = position(forSeconds: endSeconds, in: width)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                    .fill(VRollTheme.surface)
                    .frame(height: trackHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                            .stroke(VRollTheme.divider, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                    .fill(VRollTheme.accent.opacity(0.18))
                    .frame(width: max(0, endX - startX), height: trackHeight)
                    .offset(x: startX)
                    .overlay(
                        RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                            .stroke(VRollTheme.accentGradient, lineWidth: 2)
                            .frame(width: max(0, endX - startX), height: trackHeight)
                            .offset(x: startX)
                    )

                handle(at: startX)
                    .gesture(handleGesture(for: .start, in: width))
                handle(at: endX)
                    .gesture(handleGesture(for: .end, in: width))
            }
            .frame(height: trackHeight)
            // Name the track's coordinate space so the drag location
            // resolves against the FULL slider width, not the 14pt
            // handle the gesture is attached to. Without this every
            // touch on the end handle reports x≈7pt, snapping the end
            // to ~0s and collapsing the range.
            .coordinateSpace(name: trackSpaceName)
        }
    }

    private let trackSpaceName = "trimSlider"

    private func handle(at x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(VRollTheme.accentGradient)
            .frame(width: handleWidth, height: trackHeight + 16)
            .overlay(
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: 3, height: 18)
            )
            .shadow(color: VRollTheme.accent.opacity(0.4), radius: 8, y: 2)
            .offset(x: x - handleWidth / 2, y: -8)
    }

    private enum Edge { case start, end }

    private func handleGesture(for edge: Edge, in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(trackSpaceName))
            .onChanged { value in
                isScrubbing = true
                let seconds = seconds(for: value.location.x, in: width)
                switch edge {
                case .start:
                    startSeconds = min(max(0, seconds), max(0, endSeconds - 0.1))
                case .end:
                    endSeconds = max(min(totalSeconds, seconds), startSeconds + 0.1)
                }
            }
            .onEnded { _ in
                isScrubbing = false
            }
    }

    private func position(forSeconds seconds: Double, in width: CGFloat) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(seconds / totalSeconds) * width
    }

    private func seconds(for x: CGFloat, in width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        let clamped = min(max(0, x), width)
        return Double(clamped / width) * totalSeconds
    }
}
