//
//  VideoCompositionBuilder.swift
//  Feature
//
//  Single source of truth for the AVFoundation composition graph.
//  Both the export pipeline (`AVFoundationVideoEditorEngine`) and the
//  live `VideoPreviewEngine` consume this — guaranteeing the user sees
//  in preview exactly what the export produces.
//
//  The builder is `Sendable` and stateless. Callers pass a
//  `VideoMergePlan`, get back a composition + video composition pair
//  ready to plug into either an `AVAssetExportSession` or an
//  `AVPlayerItem`.
//

import Foundation
import AVFoundation
import CoreMedia
import QuartzCore
import UIKit
import Core

public struct VideoCompositionBuilder: Sendable {
    public struct Output: Sendable {
        public let composition: AVMutableComposition
        public let videoComposition: AVMutableVideoComposition
        public let totalDuration: CMTime
    }

    public init() {}

    /// Build the composition graph.
    ///
    /// `includeStickerCompositing`:
    ///   • `true`  — bakes sticker layers in via
    ///     `AVVideoCompositionCoreAnimationTool`. Required for export
    ///     because the export session is the only consumer that knows
    ///     how to render them.
    ///   • `false` — skips the animation tool entirely. **Required for
    ///     preview** because `AVPlayerItem` throws `NSInvalidArgument`
    ///     ("AVVideoCompositionCoreAnimationTool is for offline
    ///     rendering only") the moment you try to install it. The
    ///     preview surface paints stickers itself with a SwiftUI
    ///     overlay, so the player just needs the bare clip composition.
    public func build(plan: VideoMergePlan, includeStickerCompositing: Bool = true) async throws -> Output {
        guard !plan.clips.isEmpty else {
            throw VideoEditorError.emptyPlan
        }

        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let audioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )
        else {
            throw VideoEditorError.exportFailed("Failed to allocate composition tracks")
        }

        var cursor: CMTime = .zero
        var instructions: [AVMutableVideoCompositionInstruction] = []

        for clip in plan.clips {
            let asset = AVURLAsset(url: clip.url)
            guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
                throw VideoEditorError.noVideoTrack(clip.url)
            }
            let assetDuration = try await asset.load(.duration)
            let trim = clampedTrimRange(clip.trimRange, against: assetDuration)

            try videoTrack.insertTimeRange(trim, of: sourceVideo, at: cursor)
            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(trim, of: sourceAudio, at: cursor)
            }

            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let transform = try await aspectFillTransform(
                forSourceTrack: sourceVideo,
                fittingInto: plan.canvas.size
            )
            layerInstruction.setTransform(transform, at: cursor)

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, duration: trim.duration)
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)

            cursor = CMTimeAdd(cursor, trim.duration)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = plan.canvas.size
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(plan.canvas.frameRate))
        videoComposition.instructions = instructions

        if includeStickerCompositing && !plan.stickers.isEmpty {
            videoComposition.animationTool = await stickerAnimationTool(
                for: plan.stickers,
                canvasSize: plan.canvas.size,
                totalDuration: cursor
            )
        }

        return Output(
            composition: composition,
            videoComposition: videoComposition,
            totalDuration: cursor
        )
    }

    // MARK: - Helpers

    private func clampedTrimRange(_ requested: CMTimeRange, against assetDuration: CMTime) -> CMTimeRange {
        let assetSeconds = max(0, CMTimeGetSeconds(assetDuration))
        let requestedStart = max(0, CMTimeGetSeconds(requested.start))
        let requestedDuration = max(0.05, CMTimeGetSeconds(requested.duration))
        let start = min(requestedStart, max(0, assetSeconds - 0.05))
        let duration = min(requestedDuration, max(0.05, assetSeconds - start))
        return CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
    }

    private func aspectFillTransform(
        forSourceTrack track: AVAssetTrack,
        fittingInto canvasSize: CGSize
    ) async throws -> CGAffineTransform {
        let preferred = try await track.load(.preferredTransform)
        let naturalSize = try await track.load(.naturalSize)

        let rotated = CGRect(origin: .zero, size: naturalSize).applying(preferred)
        let orientedSize = CGSize(width: abs(rotated.width), height: abs(rotated.height))

        guard orientedSize.width > 0, orientedSize.height > 0 else {
            return preferred
        }

        let scale = max(canvasSize.width / orientedSize.width, canvasSize.height / orientedSize.height)
        let scaledSize = CGSize(width: orientedSize.width * scale, height: orientedSize.height * scale)
        let translateX = (canvasSize.width - scaledSize.width) / 2
        let translateY = (canvasSize.height - scaledSize.height) / 2

        let normalize = CGAffineTransform(translationX: -rotated.minX, y: -rotated.minY)
        let scaling = CGAffineTransform(scaleX: scale, y: scale)
        let centering = CGAffineTransform(translationX: translateX, y: translateY)

        return preferred
            .concatenating(normalize)
            .concatenating(scaling)
            .concatenating(centering)
    }

    @MainActor
    private func stickerAnimationTool(
        for stickers: [StickerLayer],
        canvasSize: CGSize,
        totalDuration: CMTime
    ) -> AVVideoCompositionCoreAnimationTool {
        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: canvasSize)

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: canvasSize)
        parentLayer.addSublayer(videoLayer)

        for sticker in stickers {
            let layer = StickerLayerFactory.makeLayer(
                from: sticker,
                canvasSize: canvasSize,
                totalDuration: totalDuration
            )
            parentLayer.addSublayer(layer)
        }

        return AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )
    }
}
