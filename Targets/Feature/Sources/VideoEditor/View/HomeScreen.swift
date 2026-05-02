//
//  HomeScreen.swift
//  Feature
//
//  Entry screen. Hero / empty state when there are no clips, otherwise
//  a glanceable clip strip with drag-reorder. The "Continue" CTA pushes
//  EditorRoute.editor onto the navigation stack.
//

import SwiftUI
import Core

public struct HomeScreen: View {
    @Bindable var viewModel: VideoEditorViewModel
    @Binding var path: [EditorRoute]

    @State private var trimmingClip: VideoClip?

    public init(viewModel: VideoEditorViewModel, path: Binding<[EditorRoute]>) {
        self.viewModel = viewModel
        self._path = path
    }

    public var body: some View {
        ZStack {
            VRollTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    if viewModel.clips.isEmpty {
                        EmptyStateView(
                            systemImage: "rectangle.stack.badge.play",
                            title: FeatureStrings.Home.Empty.title,
                            subtitle: FeatureStrings.Home.Empty.subtitle
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        clipBoard
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(VRollTheme.Motion.soft, value: viewModel.clips.isEmpty)

                bottomBar
            }
            .padding(.horizontal, VRollTheme.Spacing.m)
            .padding(.bottom, VRollTheme.Spacing.m)
        }
        .preferredColorScheme(.dark)
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
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(FeatureStrings.App.title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(VRollTheme.textPrimary)
                Text(FeatureStrings.App.tagline)
                    .font(.subheadline)
                    .foregroundStyle(VRollTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(VRollTheme.accentGradient)
        }
        .padding(.top, VRollTheme.Spacing.s)
        .padding(.bottom, VRollTheme.Spacing.l)
    }

    // MARK: - Clip board

    @ViewBuilder
    private var clipBoard: some View {
        VStack(alignment: .leading, spacing: VRollTheme.Spacing.m) {
            HStack {
                Text(FeatureStrings.Home.Clips.title)
                    .font(.headline)
                    .foregroundStyle(VRollTheme.textPrimary)
                Spacer()
                Label(
                    "\(viewModel.clips.count)",
                    systemImage: "film.stack"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(VRollTheme.textSecondary)
                .labelStyle(.titleAndIcon)
            }
            .padding(.horizontal, VRollTheme.Spacing.xs)

            ClipThumbnailRow(
                clips: viewModel.clips,
                onRemove: { clip in
                    withAnimation(VRollTheme.Motion.snappy) {
                        viewModel.remove(clip: clip)
                    }
                },
                onReorder: viewModel.move(clipID:before:),
                onTap: { clip in
                    trimmingClip = clip
                }
            )
            .frame(height: 144)

            VStack(alignment: .leading, spacing: 2) {
                Text(FeatureStrings.Home.Reorder.hint)
                Text(FeatureStrings.Home.Tap.To.trim)
            }
            .font(.caption)
            .foregroundStyle(VRollTheme.textTertiary)
            .padding(.horizontal, VRollTheme.Spacing.m)
        }
        .padding(VRollTheme.Spacing.m)
        .background(VRollTheme.surface, in: RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: VRollTheme.Spacing.s) {
            VideoClipPickerButton(
                maxSelectionCount: 10,
                onPicked: { urls in
                    await viewModel.ingest(urls: urls)
                }
            ) {
                pickerLabel
            }

            if !viewModel.clips.isEmpty {
                PrimaryActionButton(
                    FeatureStrings.Home.Continue.action,
                    systemImage: "arrow.right.circle.fill",
                    style: .filled
                ) {
                    path.append(.editor)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(VRollTheme.Motion.snappy, value: viewModel.clips.isEmpty)
    }

    @ViewBuilder
    private var pickerLabel: some View {
        HStack(spacing: VRollTheme.Spacing.s) {
            Image(systemName: viewModel.clips.isEmpty ? "plus.rectangle.on.rectangle.fill" : "plus.circle")
                .font(.body.weight(.semibold))
            Text(viewModel.clips.isEmpty ? FeatureStrings.Home.Add.first : FeatureStrings.Home.Add.more)
                .font(.body.weight(.semibold))
        }
        .foregroundStyle(viewModel.clips.isEmpty ? .white : VRollTheme.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background {
            if viewModel.clips.isEmpty {
                VRollTheme.accentGradient
            } else {
                VRollTheme.surface
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))
        .overlay {
            if !viewModel.clips.isEmpty {
                RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous)
                    .stroke(VRollTheme.divider, lineWidth: 1)
            }
        }
        .shadow(
            color: viewModel.clips.isEmpty ? VRollTheme.accent.opacity(0.35) : .clear,
            radius: 18,
            y: 8
        )
    }
}
