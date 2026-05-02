//
//  AVFoundationVideoEditorEngine.swift
//  Feature
//
//  Export pipeline. The composition graph itself is built by
//  `VideoCompositionBuilder` so the live preview engine stays in sync
//  with what the export produces — there is exactly one place where
//  AVMutableComposition + AVMutableVideoComposition come together.
//

import Foundation
import AVFoundation
import Core

public struct AVFoundationVideoEditorEngine: VideoEditorEngine {
    private let builder: VideoCompositionBuilder

    public init(builder: VideoCompositionBuilder = VideoCompositionBuilder()) {
        self.builder = builder
    }

    public func validate(_ plan: VideoMergePlan) throws {
        guard !plan.clips.isEmpty else {
            throw VideoEditorError.emptyPlan
        }
    }

    public func merge(
        plan: VideoMergePlan,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        try validate(plan)

        let output = try await builder.build(plan: plan)
        let outputURL = ScratchStorage.newExportURL(extension: "mp4")

        guard let session = AVAssetExportSession(
            asset: output.composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw VideoEditorError.exportFailed("Could not create export session")
        }
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = output.videoComposition
        session.shouldOptimizeForNetworkUse = true

        return try await runExport(session: session, progress: progress)
    }

    private func runExport(
        session: AVAssetExportSession,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        let progressTask = Task {
            while !Task.isCancelled {
                let value = Double(session.progress)
                await progress(value)
                if session.status == .completed || session.status == .failed || session.status == .cancelled {
                    return
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer { progressTask.cancel() }

        await session.export()

        switch session.status {
        case .completed:
            await progress(1.0)
            guard let url = session.outputURL else {
                throw VideoEditorError.exportFailed("Missing output URL after export")
            }
            return url
        case .cancelled:
            throw VideoEditorError.cancelled
        default:
            throw VideoEditorError.exportFailed(session.error?.localizedDescription ?? "Unknown export failure")
        }
    }
}
