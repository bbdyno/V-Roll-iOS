//
//  ExportScreen.swift
//  Feature
//
//  Final step. Auto-starts the merge on appear, shows a gradient ring
//  while rendering, then a celebratory completion card with Share /
//  Save actions. We use ShareLink rather than UIActivityViewController
//  so we get the system's contextual share sheet for free.
//

import SwiftUI
import AVKit
import Core

public struct ExportScreen: View {
    @Bindable var viewModel: VideoEditorViewModel
    @Binding var path: [EditorRoute]

    @State private var hasStarted = false
    @State private var saveConfirmation: SaveConfirmation?

    public init(viewModel: VideoEditorViewModel, path: Binding<[EditorRoute]>) {
        self.viewModel = viewModel
        self._path = path
    }

    public var body: some View {
        ZStack {
            VRollTheme.background.ignoresSafeArea()

            VStack(spacing: VRollTheme.Spacing.xl) {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, VRollTheme.Spacing.l)
        }
        .navigationTitle(FeatureStrings.Export.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(VRollTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await viewModel.startMerge()
        }
        .alert(item: $saveConfirmation) { confirmation in
            Alert(
                title: Text(confirmation.title),
                message: Text(confirmation.message),
                dismissButton: .default(Text(FeatureStrings.Common.close))
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .rendering(let progress):
            renderingCard(progress: progress)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .completed(let url):
            completedCard(url: url)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .failed(let message):
            failureCard(message: message)
                .transition(.opacity)
        case .idle, .ready, .importing:
            preparingCard
                .transition(.opacity)
        }
    }

    // MARK: - States

    @ViewBuilder
    private var preparingCard: some View {
        VStack(spacing: VRollTheme.Spacing.l) {
            ProgressView()
                .controlSize(.large)
                .tint(VRollTheme.accent)
            Text(FeatureStrings.Export.preparing)
                .font(.headline)
                .foregroundStyle(VRollTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func renderingCard(progress: Double) -> some View {
        VStack(spacing: VRollTheme.Spacing.xl) {
            CircularProgressRing(
                progress: progress,
                lineWidth: 14,
                centerLabel: FeatureStrings.Export.rendering
            )
            .frame(width: 220, height: 220)

            VStack(spacing: VRollTheme.Spacing.s) {
                Text(FeatureStrings.Export.Rendering.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VRollTheme.textPrimary)
                Text(FeatureStrings.Export.Rendering.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VRollTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    @ViewBuilder
    private func completedCard(url: URL) -> some View {
        VStack(spacing: VRollTheme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(VRollTheme.accent.opacity(0.15))
                    .frame(width: 160, height: 160)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(VRollTheme.accentGradient)
                    .symbolEffect(.bounce, value: url)
            }

            VStack(spacing: VRollTheme.Spacing.s) {
                Text(FeatureStrings.Export.Completed.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VRollTheme.textPrimary)
                Text(FeatureStrings.Export.Completed.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(VRollTheme.textSecondary)
            }

            VStack(spacing: VRollTheme.Spacing.s) {
                ShareLink(item: url) {
                    HStack(spacing: VRollTheme.Spacing.s) {
                        Image(systemName: "square.and.arrow.up")
                        Text(FeatureStrings.Export.share)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(VRollTheme.accentGradient, in: RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))
                    .shadow(color: VRollTheme.accent.opacity(0.35), radius: 18, y: 8)
                }

                PrimaryActionButton(
                    FeatureStrings.Export.Save.To.photos,
                    systemImage: "square.and.arrow.down",
                    style: .ghost
                ) {
                    Task {
                        await viewModel.saveCurrentExportToLibrary()
                        saveConfirmation = SaveConfirmation(
                            title: FeatureStrings.Export.Saved.title,
                            message: FeatureStrings.Export.Saved.message
                        )
                    }
                }

                Button {
                    path.removeAll()
                } label: {
                    Text(FeatureStrings.Export.done)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(VRollTheme.textSecondary)
                        .padding(.vertical, VRollTheme.Spacing.s)
                }
            }
            .padding(.top, VRollTheme.Spacing.m)
        }
    }

    @ViewBuilder
    private func failureCard(message: String) -> some View {
        VStack(spacing: VRollTheme.Spacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.orange)
            Text(FeatureStrings.Export.Failed.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(VRollTheme.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(VRollTheme.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryActionButton(
                FeatureStrings.Export.retry,
                systemImage: "arrow.clockwise",
                style: .filled
            ) {
                Task { await viewModel.startMerge() }
            }
        }
    }

    private struct SaveConfirmation: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}
