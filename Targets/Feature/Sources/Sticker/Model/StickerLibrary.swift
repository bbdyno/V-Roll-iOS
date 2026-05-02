//
//  StickerLibrary.swift
//  Feature
//

import Foundation

public struct StickerLibrary: Sendable {
    public let stickers: [Sticker]

    public init(stickers: [Sticker]) {
        self.stickers = stickers
    }

    public static func bundled() -> StickerLibrary {
        StickerLibrary(stickers: [
            Sticker(kind: .emoji("🎬"), displayName: "Clapperboard"),
            Sticker(kind: .emoji("🔥"), displayName: "Fire"),
            Sticker(kind: .emoji("⭐️"), displayName: "Star"),
            Sticker(kind: .emoji("💜"), displayName: "Heart"),
            Sticker(kind: .systemImage(name: "sparkles"), displayName: "Sparkles"),
            Sticker(kind: .systemImage(name: "bolt.fill"), displayName: "Bolt"),
            Sticker(kind: .text("V-Roll"), displayName: "Brand")
        ])
    }
}
