//
//  StickerOverlayCanvas.swift
//  Feature
//
//  In-app preview of where stickers will land in the exported video.
//  Coordinates are normalized so the same placement values can be sent
//  straight to the AVFoundation merge engine without any conversion.
//

import SwiftUI
import Core

struct StickerOverlayCanvas: View {
    @Binding var placements: [StickerLayer]
    let canvasAspect: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.6)
                    .clipShape(RoundedRectangle(cornerRadius: VRollTheme.Radius.large, style: .continuous))

                ForEach($placements) { $placement in
                    StickerHandle(placement: $placement, canvasSize: proxy.size)
                }
            }
        }
        .aspectRatio(canvasAspect, contentMode: .fit)
    }
}

private struct StickerHandle: View {
    @Binding var placement: StickerLayer
    let canvasSize: CGSize

    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        let center = CGPoint(
            x: placement.normalizedCenter.x * canvasSize.width + dragOffset.width,
            y: placement.normalizedCenter.y * canvasSize.height + dragOffset.height
        )

        glyph
            .frame(width: placement.sizePoints, height: placement.sizePoints)
            .rotationEffect(.radians(placement.rotation))
            .position(center)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let newX = (placement.normalizedCenter.x * canvasSize.width + value.translation.width) / canvasSize.width
                        let newY = (placement.normalizedCenter.y * canvasSize.height + value.translation.height) / canvasSize.height
                        placement.normalizedCenter = CGPoint(
                            x: min(max(newX, 0), 1),
                            y: min(max(newY, 0), 1)
                        )
                    }
            )
    }

    @ViewBuilder
    private var glyph: some View {
        switch placement.sticker.kind {
        case .emoji(let value), .text(let value):
            Text(value)
                .font(.system(size: placement.sizePoints * 0.6))
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: placement.sizePoints * 0.6, weight: .semibold))
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
