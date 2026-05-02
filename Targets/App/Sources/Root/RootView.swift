//
//  RootView.swift
//  V-Roll
//
//  Owns the editor's NavigationStack so the same VideoEditorViewModel
//  instance is shared across Home → Editor → Export. Each screen reads
//  and mutates that VM directly; the path drives only navigation.
//

import SwiftUI
import Core
import Feature

public struct RootView: View {
    @Environment(AppContainer.self) private var container

    @State private var path: [EditorRoute] = []
    @State private var viewModel: VideoEditorViewModel?

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let viewModel {
                    HomeScreen(viewModel: viewModel, path: $path)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            .navigationDestination(for: EditorRoute.self) { route in
                if let viewModel {
                    switch route {
                    case .editor:
                        MainEditorView(viewModel: viewModel, path: $path)
                    case .export:
                        ExportScreen(viewModel: viewModel, path: $path)
                    }
                }
            }
        }
        .tint(VRollTheme.accent)
        .preferredColorScheme(.dark)
        .task {
            if viewModel == nil {
                viewModel = VideoEditorViewModel(
                    engine: container.videoEditorEngine,
                    stickerLibrary: container.stickerLibrary,
                    mediaLibrary: container.mediaLibrary
                )
            }
        }
    }
}
