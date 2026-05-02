//
//  StickerTrackView.swift
//  Feature
//
//  Bottom track of the multi-track timeline. Sticker layers can sit
//  anywhere on the merged timeline (unlike video clips, which are
//  sequential), so this track is a `ZStack` with absolute X-offsets
//  driven by `timeRange.start * pixelsPerSecond`.
//
//  Per-segment gestures:
//   • drag body  → translate `timeRange.start` (length preserved)
//   • drag left  → resize start, end fixed
//   • drag right → resize end, start fixed
//

import SwiftUI
import CoreMedia
import Core

struct StickerTrackView: View {
    let layers: [StickerLayer]
    let totalSeconds: Double
    let pixelsPerSecond: CGFloat
    @Binding var selectedLayerID: UUID?
    let onUpdate: (UUID, CMTimeRange) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Track background — full timeline width so the track area
            // stays tappable even when no sticker covers a region.
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(VRollTheme.surface)
                .frame(
                    width: max(40, CGFloat(totalSeconds) * pixelsPerSecond),
                    height: 40
                )

            ForEach(layers) { layer in
                StickerSegment(
                    layer: layer,
                    totalSeconds: totalSeconds,
                    pixelsPerSecond: pixelsPerSecond,
                    isSelected: selectedLayerID == layer.id,
                    onTap: {
                        withAnimation(VRollTheme.Motion.snappy) {
                            selectedLayerID = layer.id
                        }
                    },
                    onUpdate: { range in onUpdate(layer.id, range) }
                )
            }
        }
        .frame(height: 40)
    }
}

private struct StickerSegment: View {
    let layer: StickerLayer
    let totalSeconds: Double
    let pixelsPerSecond: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onUpdate: (CMTimeRange) -> Void

    @State private var dragAnchor: (start: Double, duration: Double)?

    private var startSeconds: Double { CMTimeGetSeconds(layer.timeRange.start) }
    private var durationSeconds: Double { CMTimeGetSeconds(layer.timeRange.duration) }

    var body: some View {
        let startX = CGFloat(startSeconds) * pixelsPerSecond
        let width = max(28, CGFloat(durationSeconds) * pixelsPerSecond)

        ZStack {
            Capsule()
                .fill(VRollTheme.accentGradient.opacity(0.85))

            HStack(spacing: 4) {
                glyph
                    .frame(width: 16, height: 16)
                Text(String(format: "%.1fs", durationSeconds))
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)

            if isSelected {
                HStack {
                    edgeHandle(.start)
                    Spacer()
                    edgeHandle(.end)
                }
            }
        }
        .frame(width: width, height: 32)
        .overlay(
            Capsule()
                .stroke(isSelected ? .white : .clear, lineWidth: 1.5)
        )
        .shadow(color: isSelected ? VRollTheme.accent.opacity(0.5) : .clear, radius: 8, y: 2)
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(VRollTheme.Motion.snappy, value: isSelected)
        .offset(x: startX, y: 4)
        .onTapGesture(perform: onTap)
        .gesture(bodyGesture)
    }

    @ViewBuilder
    private var glyph: some View {
        switch layer.sticker.kind {
        case .emoji(let value), .text(let value):
            Text(value).font(.system(size: 14))
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        case .image(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private enum Edge { case start, end }

    @ViewBuilder
    private func edgeHandle(_ edge: Edge) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: 3, height: 18)
            .padding(.horizontal, 4)
            .contentShape(Rectangle().inset(by: -10))
            .gesture(edgeGesture(for: edge))
    }

    private var bodyGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragAnchor == nil { dragAnchor = (startSeconds, durationSeconds) }
                guard let anchor = dragAnchor else { return }
                let deltaSeconds = Double(value.translation.width / pixelsPerSecond)
                var newStart = anchor.start + deltaSeconds
                newStart = min(max(0, newStart), max(0, totalSeconds - anchor.duration))
                commit(start: newStart, duration: anchor.duration)
            }
            .onEnded { _ in dragAnchor = nil }
    }

    private func edgeGesture(for edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragAnchor == nil { dragAnchor = (startSeconds, durationSeconds) }
                guard let anchor = dragAnchor else { return }
                let deltaSeconds = Double(value.translation.width / pixelsPerSecond)
                let anchorEnd = anchor.start + anchor.duration

                switch edge {
                case .start:
                    let newStart = max(0, min(anchor.start + deltaSeconds, anchorEnd - 0.1))
                    commit(start: newStart, duration: anchorEnd - newStart)
                case .end:
                    let newEnd = max(anchor.start + 0.1, min(totalSeconds, anchorEnd + deltaSeconds))
                    commit(start: anchor.start, duration: newEnd - anchor.start)
                }
            }
            .onEnded { _ in dragAnchor = nil }
    }

    private func commit(start: Double, duration: Double) {
        let range = CMTimeRange(
            start: CMTime(seconds: max(0, start), preferredTimescale: 600),
            duration: CMTime(seconds: max(0.1, duration), preferredTimescale: 600)
        )
        onUpdate(range)
    }
}
