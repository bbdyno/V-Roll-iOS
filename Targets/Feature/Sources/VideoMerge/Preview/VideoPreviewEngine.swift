//
//  VideoPreviewEngine.swift
//  Feature
//
//  Live, scrubbable preview powered by `AVPlayer`. Whenever the editor
//  view model mutates clips or sticker layers, callers push a new
//  `VideoMergePlan` through `update(plan:)`. Plan changes funnel
//  through a Combine `PassthroughSubject` with a 120ms debounce so
//  that rapid trim/drag gestures collapse into a single composition
//  rebuild — important because each rebuild calls
//  `replaceCurrentItem(with:)`, which is non-trivial.
//
//  The engine uses Combine in three places:
//   • debounced plan rebuild (PassthroughSubject + .debounce)
//   • play/pause state mirror (KVO on `player.rate` via .publisher(for:))
//   • current-time tick (AVPlayer periodic time observer — callback
//     based, not Combine, but its updates feed @Observable state for
//     SwiftUI to read directly)
//
//  Composition graph is built by `VideoCompositionBuilder`, which is
//  also what the export pipeline uses — so what the user previews is
//  what the .mp4 contains, frame for frame.
//

import Foundation
import AVFoundation
import Combine
import Observation
import Core

@Observable
@MainActor
public final class VideoPreviewEngine {
    public let player: AVPlayer

    public private(set) var currentTime: CMTime = .zero
    public private(set) var duration: CMTime = .zero
    public private(set) var isPlaying: Bool = false

    @ObservationIgnored private let planSubject = PassthroughSubject<VideoMergePlan, Never>()
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private let builder: VideoCompositionBuilder
    @ObservationIgnored private var lastPlanSignature: PlanSignature?
    /// Set while `rebuild` is mid-flight so the periodic time observer
    /// doesn't poison `currentTime` with the half-loaded item's
    /// transient position.
    @ObservationIgnored private var isRebuilding = false

    public init(builder: VideoCompositionBuilder = VideoCompositionBuilder()) {
        self.builder = builder
        let avPlayer = AVPlayer()
        avPlayer.actionAtItemEnd = .pause
        self.player = avPlayer
        configurePipeline()
        configureTimeObserver()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    // MARK: - Public API

    /// Push the current plan into the engine. Calls coalesce inside
    /// the 120ms debounce window — safe to call from `.onChange`
    /// every keystroke / gesture tick.
    public func update(plan: VideoMergePlan) {
        planSubject.send(plan)
    }

    public func togglePlayback() {
        if player.rate == 0 {
            // If the playhead is past the end, restart from zero —
            // matches the way every social editor behaves.
            if duration > .zero, currentTime >= duration {
                player.seek(to: .zero)
            }
            player.play()
        } else {
            player.pause()
        }
    }

    public func seek(to time: CMTime) {
        guard time.isNumeric else { return }
        let target = clamp(time, in: .zero, max: duration)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = target
    }

    // MARK: - Pipeline wiring

    private func configurePipeline() {
        planSubject
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] plan in
                guard let self else { return }
                Task { @MainActor in
                    await self.rebuild(plan: plan)
                }
            }
            .store(in: &cancellables)

        player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.isPlaying = rate != 0
            }
            .store(in: &cancellables)
    }

    private func configureTimeObserver() {
        // ~30fps tick. Higher cadence is wasted here since SwiftUI only
        // re-renders when @Observable state changes anyway.
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            // AVPlayer briefly emits CMTime.invalid between item
            // replacement and the new item becoming ready. Propagating
            // it would set CMTimeGetSeconds → NaN, which then poisons
            // every layout that multiplies by pixelsPerSecond.
            guard time.isNumeric else { return }
            // Callback runs on main *thread*; assume isolation to write
            // into MainActor-isolated state.
            MainActor.assumeIsolated {
                guard let self else { return }
                // Don't accept time updates while we're swapping items —
                // the rebuild path is the authoritative writer.
                guard !self.isRebuilding else { return }
                self.currentTime = time
            }
        }
    }

    private func rebuild(plan: VideoMergePlan) async {
        let signature = PlanSignature(plan: plan)
        guard signature != lastPlanSignature else { return }
        lastPlanSignature = signature

        guard !plan.clips.isEmpty else {
            player.pause()
            player.replaceCurrentItem(with: nil)
            duration = .zero
            currentTime = .zero
            return
        }

        isRebuilding = true
        defer { isRebuilding = false }

        do {
            // forPreview = AVVideoCompositionCoreAnimationTool is for
            // export only — installing it on AVPlayerItem throws hard.
            // The preview surface paints stickers via SwiftUI overlay.
            let output = try await builder.build(plan: plan, includeStickerCompositing: false)
            let item = AVPlayerItem(asset: output.composition)
            item.videoComposition = output.videoComposition

            // First load: snap to .zero so the user lands on frame 0.
            // Subsequent rebuilds preserve the playhead so an in-flight
            // trim drag doesn't yank it back to the start.
            let isFirstItem = (player.currentItem == nil)
            let preserved: CMTime = isFirstItem ? .zero : (currentTime.isNumeric ? currentTime : .zero)

            player.replaceCurrentItem(with: item)
            duration = output.totalDuration
            // Optimistic reset — the seek below corrects this once the
            // player accepts the new position. Clears any stale value
            // a periodic-observer tick could have left between rebuilds.
            currentTime = .zero

            let clamped = clamp(preserved, in: .zero, max: output.totalDuration)
            await player.seek(to: clamped, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = clamped
        } catch {
            AppLogger.shared.error("Preview rebuild failed: \(error.localizedDescription)")
        }
    }

    private func clamp(_ time: CMTime, in lower: CMTime, max upper: CMTime) -> CMTime {
        if upper <= .zero { return .zero }
        if time < lower { return lower }
        if time > upper { return upper }
        return time
    }
}

// MARK: - Plan signature

/// Coarse fingerprint of a plan so we can short-circuit no-op rebuilds.
/// Includes only the fields that actually change the AVFoundation graph
/// — sticker positions/rotation/size DO matter (sticker compositor
/// reads them), so they are part of the signature too.
private struct PlanSignature: Hashable {
    let clips: [ClipSignature]
    let stickers: [StickerSignature]

    init(plan: VideoMergePlan) {
        clips = plan.clips.map(ClipSignature.init)
        stickers = plan.stickers.map(StickerSignature.init)
    }

    struct ClipSignature: Hashable {
        let id: UUID
        let url: URL
        let startSeconds: Double
        let durationSeconds: Double

        init(_ clip: VideoClip) {
            id = clip.id
            url = clip.url
            startSeconds = CMTimeGetSeconds(clip.trimRange.start)
            durationSeconds = CMTimeGetSeconds(clip.trimRange.duration)
        }
    }

    struct StickerSignature: Hashable {
        let id: UUID
        let kindHash: Int
        let centerX: CGFloat
        let centerY: CGFloat
        let size: CGFloat
        let rotation: CGFloat
        let startSeconds: Double
        let durationSeconds: Double

        init(_ layer: StickerLayer) {
            id = layer.id
            kindHash = layer.sticker.kind.hashValue
            centerX = layer.normalizedCenter.x
            centerY = layer.normalizedCenter.y
            size = layer.sizePoints
            rotation = layer.rotation
            startSeconds = CMTimeGetSeconds(layer.timeRange.start)
            durationSeconds = CMTimeGetSeconds(layer.timeRange.duration)
        }
    }
}
