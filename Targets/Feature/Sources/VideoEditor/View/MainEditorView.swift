//
//  MainEditorView.swift
//  Feature
//
//  The full editor surface: AVPlayer preview at the top, transport
//  bar in the middle, multi-track timeline at the bottom. Owns the
//  `VideoPreviewEngine` instance for this session and is responsible
//  for piping `VideoEditorViewModel` mutations through to it.
//
//  Plan-change → preview-rebuild plumbing:
//   1. ViewModel (@Observable) mutates `clips` / `stickers`.
//   2. SwiftUI re-renders this view because the composed plan reads
//      both arrays.
//   3. `.onChange(of: planFingerprint)` fires.
//   4. `preview.update(plan:)` sends the plan through a Combine
//      `PassthroughSubject`, which debounces 120ms before rebuilding
//      the AVPlayerItem.
//
//  We bypass SwiftUI's `Equatable` array diffing for the change
//  detection because `VideoMergePlan` doesn't synthesise `Equatable`
//  meaningfully (CMTimeRange isn't `Equatable` in older SDKs); a
//  hash-based fingerprint string is good enough.
//

import SwiftUI
import AVFoundation
import CoreMedia
import Core

public struct MainEditorView: View {
    @Bindable var viewModel: VideoEditorViewModel
    @Binding var path: [EditorRoute]

    @State private var preview = VideoPreviewEngine()
    @State private var selectedClipID: UUID?
    @State private var selectedStickerID: UUID?
    @State private var isStickerPickerPresented = false
    @State private var trimmingClip: VideoClip?

    public init(viewModel: VideoEditorViewModel, path: Binding<[EditorRoute]>) {
        self.viewModel = viewModel
        self._path = path
    }

    public var body: some View {
        ZStack {
            VRollTheme.background.ignoresSafeArea()

            VStack(spacing: VRollTheme.Spacing.m) {
                playerCard
                    .padding(.horizontal, VRollTheme.Spacing.m)
                    .padding(.top, VRollTheme.Spacing.s)

                middleBar

                contextActions

                Divider()
                    .background(VRollTheme.divider)

                MultiTrackTimelineView(
                    viewModel: viewModel,
                    preview: preview,
                    selectedClipID: $selectedClipID,
                    selectedStickerID: $selectedStickerID
                )
                .frame(maxHeight: 220)
            }
        }
        .navigationTitle(FeatureStrings.Editor.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(VRollTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    path.append(.export)
                } label: {
                    Label(FeatureStrings.Editor.Export.action, systemImage: "arrow.up.forward.app.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(VRollTheme.accent)
                }
            }
        }
        .sheet(isPresented: $isStickerPickerPresented) {
            StickerPickerView(
                library: viewModel.stickerLibrary,
                onPick: { sticker in
                    withAnimation(VRollTheme.Motion.snappy) {
                        viewModel.addSticker(sticker)
                    }
                },
                onPickImageData: { data in
                    withAnimation(VRollTheme.Motion.snappy) {
                        viewModel.addImageSticker(data: data)
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $trimmingClip) { clip in
            NavigationStack {
                ClipTrimmerView(clip: clip) { range in
                    withAnimation(VRollTheme.Motion.snappy) {
                        viewModel.updateTrim(for: clip.id, to: range)
                    }
                }
            }
            .presentationDetents([.large])
        }
        .preferredColorScheme(.dark)
        .task {
            preview.update(plan: currentPlan)
        }
        .onChange(of: planFingerprint) { _, _ in
            preview.update(plan: currentPlan)
        }
    }

    // MARK: - Player

    @ViewBuilder
    private var playerCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous)
                .fill(Color.black)

            PlayerLayerView(player: preview.player)
                .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))

            // Sticker preview is painted here, NOT through the player's
            // video composition: AVVideoCompositionCoreAnimationTool is
            // offline-only and AVPlayerItem will reject it.
            StickerPlaybackOverlay(
                layers: viewModel.stickers,
                currentTime: preview.currentTime
            )
            .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))

            if viewModel.clips.isEmpty {
                VStack(spacing: VRollTheme.Spacing.s) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 36))
                    Text(FeatureStrings.Editor.Preview.hint)
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.55))
            }
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous)
                .stroke(VRollTheme.divider, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
    }

    // MARK: - Middle bar

    @ViewBuilder
    private var middleBar: some View {
        // Transport sits centred on its own row — keeps the capsule
        // hugging its natural width, no fighting with side buttons.
        HStack {
            Spacer(minLength: 0)
            TransportControls(preview: preview)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VRollTheme.Spacing.m)
    }

    // MARK: - Context actions

    /// Trim only appears when a clip is selected, sticker is always
    /// available. Using pill chips keeps the row compact and gives a
    /// clear "this acts on the selection" affordance.
    @ViewBuilder
    private var contextActions: some View {
        HStack(spacing: VRollTheme.Spacing.s) {
            if selectedClipID != nil {
                actionPill(
                    systemImage: "scissors",
                    title: FeatureStrings.Trim.title,
                    prominent: true
                ) {
                    guard let id = selectedClipID,
                          let clip = viewModel.clips.first(where: { $0.id == id }) else { return }
                    trimmingClip = clip
                }
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            Spacer(minLength: 0)

            actionPill(
                systemImage: "face.smiling",
                title: FeatureStrings.Editor.Add.action,
                prominent: false,
                disabled: viewModel.clips.isEmpty
            ) {
                isStickerPickerPresented = true
            }
        }
        .padding(.horizontal, VRollTheme.Spacing.m)
        .frame(height: 36)
        .animation(VRollTheme.Motion.snappy, value: selectedClipID)
    }

    @ViewBuilder
    private func actionPill(
        systemImage: String,
        title: String,
        prominent: Bool,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(prominent ? .white : VRollTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if prominent {
                    Capsule().fill(VRollTheme.accentGradient)
                } else {
                    Capsule().fill(VRollTheme.surface)
                }
            }
            .overlay {
                if !prominent {
                    Capsule().stroke(VRollTheme.divider, lineWidth: 1)
                }
            }
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .buttonStyle(.plain)
    }

    // MARK: - Plan piping

    private var currentPlan: VideoMergePlan {
        VideoMergePlan(clips: viewModel.clips, stickers: viewModel.stickers)
    }

    /// Cheap diff key for `.onChange`. Includes everything the
    /// composition graph cares about so a no-op rebuild is impossible
    /// here (the engine itself also short-circuits via PlanSignature).
    private var planFingerprint: String {
        var hasher = Hasher()
        for clip in viewModel.clips {
            hasher.combine(clip.id)
            hasher.combine(clip.url)
            hasher.combine(CMTimeGetSeconds(clip.trimRange.start))
            hasher.combine(CMTimeGetSeconds(clip.trimRange.duration))
        }
        for layer in viewModel.stickers {
            hasher.combine(layer.id)
            hasher.combine(layer.sticker.kind)
            hasher.combine(layer.normalizedCenter.x)
            hasher.combine(layer.normalizedCenter.y)
            hasher.combine(layer.sizePoints)
            hasher.combine(layer.rotation)
            hasher.combine(CMTimeGetSeconds(layer.timeRange.start))
            hasher.combine(CMTimeGetSeconds(layer.timeRange.duration))
        }
        return String(hasher.finalize())
    }
}
