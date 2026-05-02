//
//  VideoEditorEngine.swift
//  Feature
//
//  Public protocol for the video editor engine. The default
//  implementation is `AVFoundationVideoEditorEngine` — a previewable
//  stub lives in `Common/PreviewSupport.swift` for SwiftUI Previews
//  and unit tests.
//

import Foundation

public enum VideoEditorError: Error, Equatable {
    case emptyPlan
    case sourceUnreadable(URL)
    case noVideoTrack(URL)
    case exportFailed(String)
    case cancelled
}

public protocol VideoEditorEngine: Sendable {
    /// Cheap precondition check used by call sites that want to gate a UI
    /// action without actually exporting (e.g. dim the "Merge" button).
    func validate(_ plan: VideoMergePlan) throws

    /// Performs the merge and returns a temp URL pointing at an `.mp4`
    /// inside `ScratchStorage`. Progress reports a [0, 1] value on the
    /// MainActor — call sites can bind it directly to a SwiftUI view.
    func merge(
        plan: VideoMergePlan,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL
}
