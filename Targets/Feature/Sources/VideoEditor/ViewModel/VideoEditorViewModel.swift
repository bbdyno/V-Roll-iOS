//
//  VideoEditorViewModel.swift
//  Feature
//

import Foundation
import Observation
import AVFoundation
import CoreMedia
import Core

@Observable
@MainActor
public final class VideoEditorViewModel {
    public enum State: Equatable {
        case idle
        case importing
        case ready
        case rendering(progress: Double)
        case completed(exportURL: URL)
        case failed(message: String)
    }

    public private(set) var state: State = .idle
    public private(set) var clips: [VideoClip] = []
    public var stickers: [StickerLayer] = []

    public let stickerLibrary: StickerLibrary

    private let engine: VideoEditorEngine
    private let mediaLibrary: MediaLibraryService

    public init(
        engine: VideoEditorEngine,
        stickerLibrary: StickerLibrary,
        mediaLibrary: MediaLibraryService
    ) {
        self.engine = engine
        self.stickerLibrary = stickerLibrary
        self.mediaLibrary = mediaLibrary
    }

    // MARK: - Clip pipeline

    public func ingest(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        state = .importing
        var loaded: [VideoClip] = []
        for url in urls {
            do {
                let asset = AVURLAsset(url: url)
                let duration = try await asset.load(.duration)
                let track = try await asset.loadTracks(withMediaType: .video).first
                let size = try await track?.load(.naturalSize) ?? .zero
                loaded.append(VideoClip(url: url, duration: duration, pixelSize: size))
            } catch {
                AppLogger.shared.warn("Skipping unreadable clip \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        clips.append(contentsOf: loaded)
        state = clips.isEmpty ? .idle : .ready
    }

    public func remove(clip: VideoClip) {
        clips.removeAll { $0.id == clip.id }
        if clips.isEmpty { state = .idle }
    }

    public func move(clipID source: UUID, before target: UUID) {
        guard source != target,
              let sourceIdx = clips.firstIndex(where: { $0.id == source }),
              var targetIdx = clips.firstIndex(where: { $0.id == target }) else {
            return
        }
        let moved = clips.remove(at: sourceIdx)
        if sourceIdx < targetIdx { targetIdx -= 1 }
        clips.insert(moved, at: targetIdx)
    }

    /// Persists a user-edited trim range for a clip. Trimming the range
    /// can shorten the merged timeline, so any sticker placement that
    /// now extends past the new total duration is clamped to fit.
    public func updateTrim(for clipID: UUID, to range: CMTimeRange) {
        guard let idx = clips.firstIndex(where: { $0.id == clipID }) else { return }
        clips[idx].trimRange = range
        clampStickersToTimeline()
    }

    /// Sum of every clip's effective (post-trim) duration. Drives the
    /// timeline UI and seeds default sticker windows.
    public var totalDuration: CMTime {
        clips.reduce(.zero) { CMTimeAdd($0, $1.effectiveDuration) }
    }

    // MARK: - Stickers

    public func addSticker(_ sticker: Sticker) {
        appendPlacement(for: sticker)
    }

    public func addImageSticker(data: Data) {
        let sticker = Sticker(
            kind: .image(data),
            displayName: "Photo Sticker"
        )
        appendPlacement(for: sticker)
    }

    public func removeSticker(_ placement: StickerLayer) {
        stickers.removeAll { $0.id == placement.id }
    }

    /// Replaces the appearance window for a placement, clamped to the
    /// merged timeline so we never produce CABasicAnimations that begin
    /// past the export's duration (those silently drop).
    public func updateTimeRange(for placementID: UUID, to range: CMTimeRange) {
        guard let idx = stickers.firstIndex(where: { $0.id == placementID }) else { return }
        stickers[idx].timeRange = clamped(range, against: totalDuration)
    }

    // Back-compat shim for legacy slider-based inspector. Slot start +
    // duration into the new `timeRange` field.
    public func updateTiming(
        for placementID: UUID,
        startSeconds: Double,
        durationSeconds: Double
    ) {
        let range = CMTimeRange(
            start: CMTime(seconds: startSeconds, preferredTimescale: 600),
            duration: CMTime(seconds: durationSeconds, preferredTimescale: 600)
        )
        updateTimeRange(for: placementID, to: range)
    }

    private func appendPlacement(for sticker: Sticker) {
        let total = CMTimeGetSeconds(totalDuration)
        let initialDuration = total > 0 ? min(3.0, total) : 3.0
        let placement = StickerLayer(
            sticker: sticker,
            normalizedCenter: CGPoint(x: 0.5, y: 0.5),
            sizePoints: 220,
            timeRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: initialDuration, preferredTimescale: 600)
            )
        )
        stickers.append(placement)
    }

    private func clampStickersToTimeline() {
        for index in stickers.indices {
            stickers[index].timeRange = clamped(
                stickers[index].timeRange,
                against: totalDuration
            )
        }
    }

    private func clamped(_ range: CMTimeRange, against total: CMTime) -> CMTimeRange {
        let totalSeconds = max(0, CMTimeGetSeconds(total))
        let start = max(0, min(CMTimeGetSeconds(range.start), max(0, totalSeconds - 0.1)))
        let duration = max(0.1, min(CMTimeGetSeconds(range.duration), max(0.1, totalSeconds - start)))
        return CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
    }

    // MARK: - Export

    public func startMerge() async {
        guard !clips.isEmpty else { return }
        state = .rendering(progress: 0)
        let plan = VideoMergePlan(clips: clips, stickers: stickers)
        do {
            let url = try await engine.merge(plan: plan) { [weak self] value in
                self?.state = .rendering(progress: value)
            }
            state = .completed(exportURL: url)
        } catch {
            AppLogger.shared.error("Merge failed: \(error.localizedDescription)")
            state = .failed(message: error.localizedDescription)
        }
    }

    public func saveCurrentExportToLibrary() async {
        guard case let .completed(url) = state else { return }
        do {
            try await mediaLibrary.saveVideoToLibrary(at: url)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }
}
