//
//  StickerPlaybackOverlay.swift
//  Feature
//
//  Read-only sticker layer renderer for the live preview surface.
//  AVPlayerItem rejects `AVVideoCompositionCoreAnimationTool` — that
//  API is offline-render-only — so the preview pipeline can't bake
//  stickers into the video stream the way export does. We compensate
//  here: a SwiftUI overlay placed on top of the player frame paints
//  every sticker whose `timeRange` contains the current playhead.
//
//  Position math matches the export-side `StickerLayerFactory` so
//  what you see at preview time matches the rendered .mp4: normalized
//  centre × frame size, sized in points, rotated about its own centre.
//

import SwiftUI
import CoreMedia
import Core

struct StickerPlaybackOverlay: View {
    let layers: [StickerLayer]
    let currentTime: CMTime

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(visibleLayers) { layer in
                    glyph(for: layer.sticker)
                        .frame(width: layer.sizePoints, height: layer.sizePoints)
                        .rotationEffect(.radians(layer.rotation))
                        .position(
                            x: layer.normalizedCenter.x * proxy.size.width,
                            y: layer.normalizedCenter.y * proxy.size.height
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: visibleLayers.map(\.id))
        }
        .allowsHitTesting(false)
    }

    private var visibleLayers: [StickerLayer] {
        layers.filter { layer in
            CMTimeRangeContainsTime(layer.timeRange, time: currentTime)
        }
    }

    @ViewBuilder
    private func glyph(for sticker: Sticker) -> some View {
        switch sticker.kind {
        case .emoji(let value), .text(let value):
            Text(value)
                .font(.system(size: 60))
                .minimumScaleFactor(0.5)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        case .systemImage(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        case .image(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
            }
        }
    }
}
