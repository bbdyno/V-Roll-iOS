//
//  ClipThumbnailRow.swift
//  Feature
//
//  Horizontal scrolling strip of clip thumbnails. Drag-and-drop reorder
//  via SwiftUI's `.draggable` / `.dropDestination` (iOS 16+). Newly
//  added clips slide in from the right; reordering animates with a
//  spring; removal fades out. We pass clip IDs as String tokens because
//  that's the smallest serialisable payload `.draggable` accepts.
//

import SwiftUI
import AVFoundation
import Core

struct ClipThumbnailRow: View {
    let clips: [VideoClip]
    let onRemove: (VideoClip) -> Void
    let onReorder: (UUID, UUID) -> Void
    let onTap: ((VideoClip) -> Void)?

    @State private var draggingID: UUID?

    init(
        clips: [VideoClip],
        onRemove: @escaping (VideoClip) -> Void,
        onReorder: @escaping (UUID, UUID) -> Void,
        onTap: ((VideoClip) -> Void)? = nil
    ) {
        self.clips = clips
        self.onRemove = onRemove
        self.onReorder = onReorder
        self.onTap = onTap
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VRollTheme.Spacing.s) {
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    ClipThumbnail(
                        clip: clip,
                        index: index + 1,
                        isDragging: draggingID == clip.id,
                        onRemove: { onRemove(clip) }
                    )
                    .onTapGesture {
                        onTap?(clip)
                    }
                    .draggable(clip.id.uuidString) {
                        ClipThumbnail(clip: clip, index: index + 1, isDragging: true, onRemove: {})
                            .opacity(0.85)
                            .onAppear { draggingID = clip.id }
                    }
                    .dropDestination(for: String.self) { items, _ in
                        defer { draggingID = nil }
                        guard let raw = items.first,
                              let sourceID = UUID(uuidString: raw) else {
                            return false
                        }
                        withAnimation(VRollTheme.Motion.snappy) {
                            onReorder(sourceID, clip.id)
                        }
                        return true
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.6).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, VRollTheme.Spacing.m)
            .animation(VRollTheme.Motion.snappy, value: clips.map(\.id))
        }
    }
}

private struct ClipThumbnail: View {
    let clip: VideoClip
    let index: Int
    let isDragging: Bool
    let onRemove: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                .fill(VRollTheme.surface)
                .frame(width: 96, height: 128)
                .overlay {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 96, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous))
                    } else {
                        ProgressView()
                            .tint(VRollTheme.textSecondary)
                    }
                }
                .overlay(alignment: .topLeading) {
                    Text("\(index)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VRollTheme.accent, in: Capsule())
                        .padding(VRollTheme.Spacing.xs)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(formatDuration(clip.effectiveDuration))
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(VRollTheme.Spacing.xs)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                        .stroke(VRollTheme.divider, lineWidth: 1)
                )

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.7))
                    .symbolRenderingMode(.palette)
            }
            .padding(VRollTheme.Spacing.xs)
        }
        .scaleEffect(isDragging ? 1.05 : 1)
        .shadow(
            color: isDragging ? VRollTheme.accent.opacity(0.45) : .black.opacity(0.4),
            radius: isDragging ? 14 : 6,
            y: isDragging ? 6 : 3
        )
        .animation(VRollTheme.Motion.snappy, value: isDragging)
        .contentShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous))
        .task(id: clip.id) {
            thumbnail = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: clip.url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 256, height: 256)
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            do {
                let cgImage = try await generator.image(at: time).image
                return UIImage(cgImage: cgImage)
            } catch {
                return nil
            }
        }.value
    }

    private func formatDuration(_ duration: CMTime) -> String {
        let seconds = max(0, CMTimeGetSeconds(duration))
        return String(format: "%.1fs", seconds)
    }
}
