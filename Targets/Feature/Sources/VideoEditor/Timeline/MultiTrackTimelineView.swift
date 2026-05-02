//
//  MultiTrackTimelineView.swift
//  Feature
//
//  Vertically stacked tracks (video on top, stickers below) wrapped in
//  a horizontal `ScrollView`. The playhead floats above both tracks
//  and reads `preview.currentTime` directly so it stays in lockstep
//  with AVPlayer.
//
//  Auto-scroll-to-follow-playhead was removed: any `scrollTo(.center)`
//  near the start fights ScrollView's content-edge clamp, which the
//  user perceives as bouncing. The timeline is short enough that a
//  manual horizontal drag is fine; we'll add zoom + smarter follow
//  later if real users actually ask for it.
//

import SwiftUI
import CoreMedia
import Core

struct MultiTrackTimelineView: View {
    @Bindable var viewModel: VideoEditorViewModel
    @Bindable var preview: VideoPreviewEngine

    @Binding var selectedClipID: UUID?
    @Binding var selectedStickerID: UUID?

    /// Horizontal density. 40pt/sec keeps a 10-second roll fully
    /// visible on a 390pt-wide iPhone with no scrolling, and trim
    /// handles still have ~40pt of clip body between them per second
    /// of footage.
    let pixelsPerSecond: CGFloat = 40

    private var totalSeconds: Double {
        max(1, CMTimeGetSeconds(viewModel.totalDuration))
    }

    private var contentWidth: CGFloat {
        max(80, CGFloat(totalSeconds) * pixelsPerSecond)
    }

    private let timelineSpaceName = "vroll-timeline"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: VRollTheme.Spacing.s) {
                    TimeRulerView(
                        totalSeconds: totalSeconds,
                        pixelsPerSecond: pixelsPerSecond
                    )

                    VideoTrackView(
                        clips: viewModel.clips,
                        pixelsPerSecond: pixelsPerSecond,
                        selectedClipID: $selectedClipID,
                        onTrim: { id, range in
                            viewModel.updateTrim(for: id, to: range)
                        },
                        onReorder: viewModel.move(clipID:before:)
                    )

                    StickerTrackView(
                        layers: viewModel.stickers,
                        totalSeconds: totalSeconds,
                        pixelsPerSecond: pixelsPerSecond,
                        selectedLayerID: $selectedStickerID,
                        onUpdate: { id, range in
                            viewModel.updateTimeRange(for: id, to: range)
                        }
                    )
                    .frame(width: contentWidth)
                }

                PlayheadView(
                    currentTime: preview.currentTime,
                    totalSeconds: totalSeconds,
                    pixelsPerSecond: pixelsPerSecond,
                    coordinateSpaceName: timelineSpaceName,
                    onScrub: { time in
                        preview.seek(to: time)
                    }
                )
                .frame(width: contentWidth, height: 130, alignment: .topLeading)
            }
            .padding(.leading, VRollTheme.Spacing.s)
            .padding(.vertical, VRollTheme.Spacing.s)
            .padding(.trailing, VRollTheme.Spacing.l)
            .coordinateSpace(name: timelineSpaceName)
        }
        .background(VRollTheme.background)
        // Clip the scroll view to its bounds so horizontal panning
        // never spills under the navigation bar / safe-area chrome.
        .clipped()
    }
}
