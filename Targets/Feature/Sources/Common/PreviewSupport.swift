//
//  PreviewSupport.swift
//  Feature
//

import SwiftUI
import Photos
import Core

#if DEBUG
struct PreviewVideoEditorEngine: VideoEditorEngine {
    func validate(_ plan: VideoMergePlan) throws {
        if plan.clips.isEmpty { throw VideoEditorError.emptyPlan }
    }

    func merge(
        plan: VideoMergePlan,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        await progress(1)
        return URL(fileURLWithPath: "/dev/null")
    }
}

struct PreviewMediaLibraryService: MediaLibraryService {
    func requestAuthorization() async -> PHAuthorizationStatus { .notDetermined }
    func saveVideoToLibrary(at url: URL) async throws {}
}

@MainActor
private func previewViewModel() -> VideoEditorViewModel {
    VideoEditorViewModel(
        engine: PreviewVideoEditorEngine(),
        stickerLibrary: StickerLibrary.bundled(),
        mediaLibrary: PreviewMediaLibraryService()
    )
}

#Preview("Home — empty") {
    StatefulPreviewWrapper([EditorRoute]()) { path in
        NavigationStack(path: path) {
            HomeScreen(viewModel: previewViewModel(), path: path)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Editor") {
    StatefulPreviewWrapper([EditorRoute]()) { path in
        NavigationStack(path: path) {
            MainEditorView(viewModel: previewViewModel(), path: path)
        }
        .preferredColorScheme(.dark)
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
#endif
