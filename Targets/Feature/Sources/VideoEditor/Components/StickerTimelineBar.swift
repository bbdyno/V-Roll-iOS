//
//  StickerTimelineBar.swift
//  Feature
//
//  Bar-style timeline editor — one row per sticker placement, each row
//  shows the merged-video duration as a horizontal track with the
//  sticker's `timeRange` rendered as a draggable segment.
//
//  Three gestures live on each segment:
//   • drag the body  → translate the whole range (start AND end shift)
//   • drag left edge → move start, end fixed
//   • drag right edge → move end, start fixed
//
//  Every gesture funnels through a single `update(_ range: CMTimeRange)`
//  callback so the parent view model gets one unambiguous source of
//  truth for the clamped range.
//

import SwiftUI
import CoreMedia
import Core

struct StickerTimelineBar: View {
    let placements: [StickerLayer]
    let totalDuration: CMTime
    let onUpdate: (UUID, CMTimeRange) -> Void
    let onRemove: (StickerLayer) -> Void

    var body: some View {
        if placements.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: VRollTheme.Spacing.s) {
                header

                ScrollView {
                    VStack(spacing: VRollTheme.Spacing.s) {
                        ForEach(placements) { placement in
                            StickerTimelineRow(
                                placement: placement,
                                totalSeconds: max(0.1, CMTimeGetSeconds(totalDuration)),
                                onUpdate: { onUpdate(placement.id, $0) },
                                onRemove: { onRemove(placement) }
                            )
                        }
                    }
                    .padding(.horizontal, VRollTheme.Spacing.m)
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(FeatureStrings.Sticker.Timeline.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VRollTheme.textPrimary)
            Spacer()
            Text(formatDuration(CMTimeGetSeconds(totalDuration)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(VRollTheme.textSecondary)
        }
        .padding(.horizontal, VRollTheme.Spacing.m)
    }

    private func formatDuration(_ seconds: Double) -> String {
        String(format: "%.1fs", max(0, seconds))
    }
}

// MARK: - Row

private struct StickerTimelineRow: View {
    let placement: StickerLayer
    let totalSeconds: Double
    let onUpdate: (CMTimeRange) -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VRollTheme.Spacing.xs) {
            HStack {
                glyph
                    .frame(width: 30, height: 30)
                Text(placement.sticker.displayName)
                    .font(.callout)
                    .foregroundStyle(VRollTheme.textPrimary)
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundStyle(VRollTheme.textSecondary)
                }
                .buttonStyle(.borderless)
            }

            BarTrack(
                startSeconds: CMTimeGetSeconds(placement.timeRange.start),
                endSeconds: CMTimeGetSeconds(placement.timeRange.start) + CMTimeGetSeconds(placement.timeRange.duration),
                totalSeconds: totalSeconds,
                onChange: onUpdate
            )
        }
        .padding(VRollTheme.Spacing.s)
        .background(VRollTheme.surface, in: RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var glyph: some View {
        switch placement.sticker.kind {
        case .emoji(let value), .text(let value):
            Text(value).font(.title3)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.title3)
                .foregroundStyle(VRollTheme.accent)
        case .image(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

// MARK: - BarTrack

private struct BarTrack: View {
    let startSeconds: Double
    let endSeconds: Double
    let totalSeconds: Double
    let onChange: (CMTimeRange) -> Void

    @State private var dragAnchor: (start: Double, end: Double)?

    private let trackHeight: CGFloat = 38
    private let handleWidth: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let startX = position(of: startSeconds, in: width)
            let endX = position(of: endSeconds, in: width)
            let segmentWidth = max(handleWidth * 2, endX - startX)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(VRollTheme.surfaceElevated)
                    .frame(height: trackHeight)

                ZStack {
                    Capsule()
                        .fill(VRollTheme.accentGradient.opacity(0.85))
                    HStack {
                        handle()
                        Spacer()
                        Text(formatDuration(endSeconds - startSeconds))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Spacer()
                        handle()
                    }
                    .padding(.horizontal, 4)
                }
                .frame(width: segmentWidth, height: trackHeight)
                .offset(x: startX)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragAnchor == nil {
                                dragAnchor = (startSeconds, endSeconds)
                            }
                            guard let anchor = dragAnchor else { return }
                            let deltaSeconds = secondsDelta(for: value.translation.width, in: width)
                            let length = anchor.end - anchor.start
                            var newStart = anchor.start + deltaSeconds
                            newStart = min(max(0, newStart), max(0, totalSeconds - length))
                            commit(start: newStart, end: newStart + length)
                        }
                        .onEnded { _ in dragAnchor = nil }
                )

                edgeHandle(at: startX, alignment: .leading) { delta in
                    let newStart = clamp(startSeconds + delta, lower: 0, upper: endSeconds - 0.1)
                    commit(start: newStart, end: endSeconds)
                }

                edgeHandle(at: endX, alignment: .trailing) { delta in
                    let newEnd = clamp(endSeconds + delta, lower: startSeconds + 0.1, upper: totalSeconds)
                    commit(start: startSeconds, end: newEnd)
                }
            }
            .frame(height: trackHeight)
        }
        .frame(height: trackHeight)
    }

    private func handle() -> some View {
        Capsule()
            .fill(.white.opacity(0.95))
            .frame(width: 3, height: 16)
    }

    private func edgeHandle(
        at x: CGFloat,
        alignment: HorizontalAlignment,
        onDrag: @escaping (Double) -> Void
    ) -> some View {
        GeometryReader { geo in
            Color.clear
                .frame(width: handleWidth * 2, height: trackHeight + 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let delta = secondsDelta(for: value.translation.width, in: geo.size.width)
                            onDrag(delta)
                        }
                )
                .offset(x: alignment == .leading ? x - handleWidth : x - handleWidth, y: -6)
        }
        .frame(width: 1, height: trackHeight)
        .allowsHitTesting(true)
    }

    private func position(of seconds: Double, in width: CGFloat) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(seconds / totalSeconds) * width
    }

    private func secondsDelta(for translationX: CGFloat, in width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(translationX / width) * totalSeconds
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(lower, value), max(lower, upper))
    }

    private func commit(start: Double, end: Double) {
        let safeStart = max(0, start)
        let safeEnd = min(totalSeconds, max(safeStart + 0.1, end))
        let range = CMTimeRange(
            start: CMTime(seconds: safeStart, preferredTimescale: 600),
            duration: CMTime(seconds: safeEnd - safeStart, preferredTimescale: 600)
        )
        onChange(range)
    }

    private func formatDuration(_ seconds: Double) -> String {
        String(format: "%.1fs", max(0, seconds))
    }
}
