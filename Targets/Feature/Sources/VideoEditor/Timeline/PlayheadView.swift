//
//  PlayheadView.swift
//  Feature
//
//  Vertical scrub line + triangular handle.
//
//  Two layout traps to be aware of:
//
//   1. The handle column has a tiny intrinsic width (14pt). Sitting it
//      directly inside a parent frame of `contentWidth` would let the
//      frame center it horizontally, putting the handle in the middle
//      of the timeline at currentTime = 0. We anchor it explicitly
//      with `HStack { VStack; Spacer }` so offset 0 maps to the
//      timeline's leading edge.
//
//   2. The drag gesture inside the 14pt-wide handle would otherwise
//      report `value.location.x` in handle-local coords. We name a
//      shared coordinate space at the timeline level and read the
//      gesture in that space so dragging the handle scrubs to the
//      timeline position the finger is actually over.
//

import SwiftUI
import CoreMedia
import Core

struct PlayheadView: View {
    let currentTime: CMTime
    let totalSeconds: Double
    let pixelsPerSecond: CGFloat
    let coordinateSpaceName: String
    let onScrub: (CMTime) -> Void

    var body: some View {
        let x = max(0, CGFloat(CMTimeGetSeconds(currentTime)) * pixelsPerSecond)

        HStack(spacing: 0) {
            handle
                .offset(x: x - 7)
                .gesture(scrubGesture)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var handle: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(VRollTheme.accentGradient)
                .frame(width: 14, height: 10)
                .shadow(color: VRollTheme.accent.opacity(0.5), radius: 4, y: 2)

            Rectangle()
                .fill(VRollTheme.accent)
                .frame(width: 2)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle().inset(by: -8))
    }

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
            .onChanged { value in
                let seconds = max(0, min(totalSeconds, Double(value.location.x / pixelsPerSecond)))
                onScrub(CMTime(seconds: seconds, preferredTimescale: 600))
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}
