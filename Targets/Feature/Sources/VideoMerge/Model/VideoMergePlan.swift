//
//  VideoMergePlan.swift
//  Feature
//

import Foundation
import CoreGraphics
import Core

public struct VideoMergePlan: Sendable {
    public let id: UUID
    public let clips: [VideoClip]
    public let stickers: [StickerLayer]
    public let canvas: RenderCanvas

    public init(
        id: UUID = UUID(),
        clips: [VideoClip],
        stickers: [StickerLayer],
        canvas: RenderCanvas = .portraitHD
    ) {
        self.id = id
        self.clips = clips
        self.stickers = stickers
        self.canvas = canvas
    }
}
