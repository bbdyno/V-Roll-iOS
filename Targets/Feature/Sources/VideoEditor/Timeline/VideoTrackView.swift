//
//  VideoTrackView.swift
//  Feature
//
//  Top track of the multi-track timeline. Each clip is rendered as a
//  block whose width is `effectiveDuration * pixelsPerSecond`. Three
//  gestures are bound:
//
//   • drag the body  → reorder clips (drop on a sibling reorders)
//   • drag left edge → trim in-point (asset-relative `trimRange.start`
//     moves; duration shrinks/grows accordingly)
//   • drag right edge → trim out-point (only `trimRange.duration`
//     changes)
//
//  Selection is reflected by a glowing accent border + slight scale —
//  premium-app polish without being noisy.
//

import SwiftUI
import AVFoundation
import CoreMedia
import Core

struct VideoTrackView: View {
    let clips: [VideoClip]
    let pixelsPerSecond: CGFloat
    @Binding var selectedClipID: UUID?
    let onTrim: (UUID, CMTimeRange) -> Void
    let onReorder: (UUID, UUID) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(clips) { clip in
                let isSelected = selectedClipID == clip.id
                ClipBlock(
                    clip: clip,
                    pixelsPerSecond: pixelsPerSecond,
                    isSelected: isSelected,
                    onTap: {
                        // Tap toggles selection — second tap deselects
                        // so the user can release a clip without having
                        // to find empty space to tap.
                        withAnimation(VRollTheme.Motion.snappy) {
                            selectedClipID = isSelected ? nil : clip.id
                        }
                    },
                    onTrim: { range in onTrim(clip.id, range) }
                )
                .modifier(ReorderableModifier(
                    clipID: clip.id,
                    isReorderEnabled: !isSelected,
                    onReorder: onReorder
                ))
            }
        }
    }
}

/// Conditionally attaches `.draggable` only when the clip is NOT
/// selected. `.draggable` wraps the view in a UIDragInteraction that
/// captures the long-press gesture before the inner trim handle's
/// `DragGesture` ever sees it — leaving the trim feeling broken. We
/// avoid the conflict by gating drag-to-reorder on selection state:
/// tap the clip → trim handles take over; tap somewhere else →
/// drag-to-reorder comes back.
private struct ReorderableModifier: ViewModifier {
    let clipID: UUID
    let isReorderEnabled: Bool
    let onReorder: (UUID, UUID) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isReorderEnabled {
            content
                .draggable(clipID.uuidString) {
                    Color.clear.frame(width: 1, height: 1)
                }
                .dropDestination(for: String.self) { items, _ in
                    handle(items)
                }
        } else {
            content
                .dropDestination(for: String.self) { items, _ in
                    handle(items)
                }
        }
    }

    private func handle(_ items: [String]) -> Bool {
        guard let raw = items.first,
              let sourceID = UUID(uuidString: raw),
              sourceID != clipID else { return false }
        withAnimation(VRollTheme.Motion.snappy) {
            onReorder(sourceID, clipID)
        }
        return true
    }
}

private struct ClipBlock: View {
    let clip: VideoClip
    let pixelsPerSecond: CGFloat
    let isSelected: Bool
    let onTap: () -> Void
    let onTrim: (CMTimeRange) -> Void

    @State private var trimAnchor: CMTimeRange?

    private var blockWidth: CGFloat {
        max(40, CGFloat(CMTimeGetSeconds(clip.effectiveDuration)) * pixelsPerSecond)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VRollTheme.accentGradient.opacity(0.78))

            HStack {
                Image(systemName: "film")
                    .font(.caption.weight(.semibold))
                Text(format(clip.effectiveDuration))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)

            // Edge handles — only visible while selected so they don't
            // visually clutter every block.
            if isSelected {
                HStack {
                    edgeHandle(.start)
                    Spacer()
                    edgeHandle(.end)
                }
            }
        }
        .frame(width: blockWidth, height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? .white : .white.opacity(0.0), lineWidth: 2)
        )
        .shadow(
            color: isSelected ? VRollTheme.accent.opacity(0.55) : .clear,
            radius: isSelected ? 12 : 0,
            y: isSelected ? 4 : 0
        )
        .scaleEffect(isSelected ? 1.03 : 1)
        .animation(VRollTheme.Motion.snappy, value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onTap)
    }

    private enum Edge { case start, end }

    @ViewBuilder
    private func edgeHandle(_ edge: Edge) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: 4, height: 28)
            .padding(.horizontal, 4)
            .contentShape(Rectangle().inset(by: -8))
            .gesture(trimGesture(for: edge))
    }

    private func trimGesture(for edge: Edge) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if trimAnchor == nil { trimAnchor = clip.trimRange }
                guard let anchor = trimAnchor else { return }
                let deltaSeconds = Double(value.translation.width / pixelsPerSecond)
                let anchorStart = CMTimeGetSeconds(anchor.start)
                let anchorDuration = CMTimeGetSeconds(anchor.duration)
                let anchorEnd = anchorStart + anchorDuration

                switch edge {
                case .start:
                    let newStart = max(0, min(anchorStart + deltaSeconds, anchorEnd - 0.1))
                    let newDuration = anchorEnd - newStart
                    onTrim(CMTimeRange(
                        start: CMTime(seconds: newStart, preferredTimescale: 600),
                        duration: CMTime(seconds: newDuration, preferredTimescale: 600)
                    ))
                case .end:
                    let newDuration = max(0.1, anchorDuration + deltaSeconds)
                    onTrim(CMTimeRange(
                        start: anchor.start,
                        duration: CMTime(seconds: newDuration, preferredTimescale: 600)
                    ))
                }
            }
            .onEnded { _ in trimAnchor = nil }
    }

    private func format(_ time: CMTime) -> String {
        String(format: "%.1fs", max(0, CMTimeGetSeconds(time)))
    }
}
