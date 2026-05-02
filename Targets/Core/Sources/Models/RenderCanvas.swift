//
//  RenderCanvas.swift
//  Core
//

import CoreGraphics

/// Output canvas the merge engine renders into. Picking 1080×1920 keeps
/// 9:16 short-form social ratios crisp on most current iPhones.
public struct RenderCanvas: Hashable, Sendable {
    public let size: CGSize
    public let frameRate: Int

    public init(size: CGSize, frameRate: Int) {
        self.size = size
        self.frameRate = frameRate
    }

    public static let portraitHD = RenderCanvas(
        size: CGSize(width: 1080, height: 1920),
        frameRate: 30
    )
}
