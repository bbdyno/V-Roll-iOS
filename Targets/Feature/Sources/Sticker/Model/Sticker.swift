//
//  Sticker.swift
//  Feature
//
//  Two distinct concepts live here:
//
//   • `Sticker` — the catalog entry. Just a kind (emoji / symbol /
//     text / image bytes) and a display name. Identity is per-source,
//     so the same bundled emoji always has the same Sticker id.
//
//   • `StickerLayer` — a placement of a Sticker on the merged
//     timeline. Identity is per-instance: dragging the same emoji
//     into the timeline twice produces two `StickerLayer`s. This is
//     what gets baked into a CALayer at composition time.
//

import Foundation
import CoreGraphics
import CoreMedia

public struct Sticker: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case emoji(String)
        case text(String)
        case systemImage(name: String)
        /// Raw image bytes loaded from the user's photo library. Stored
        /// as Data (not UIImage) so the model stays Sendable and
        /// trivially equatable.
        case image(Data)
    }

    public let id: UUID
    public let kind: Kind
    public let displayName: String

    public init(id: UUID = UUID(), kind: Kind, displayName: String) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
    }
}

public struct StickerLayer: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let sticker: Sticker

    /// Position in normalized canvas coordinates (0...1).
    public var normalizedCenter: CGPoint
    public var sizePoints: CGFloat
    public var rotation: CGFloat

    /// Window during which the sticker is visible in the merged
    /// timeline. Single CMTimeRange so engine and UI agree on one
    /// value — `start` and `duration` are derived for convenience.
    public var timeRange: CMTimeRange

    public init(
        id: UUID = UUID(),
        sticker: Sticker,
        normalizedCenter: CGPoint = CGPoint(x: 0.5, y: 0.5),
        sizePoints: CGFloat = 220,
        rotation: CGFloat = 0,
        timeRange: CMTimeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
    ) {
        self.id = id
        self.sticker = sticker
        self.normalizedCenter = normalizedCenter
        self.sizePoints = sizePoints
        self.rotation = rotation
        self.timeRange = timeRange
    }

    public var startOffset: CMTime { timeRange.start }
    public var duration: CMTime { timeRange.duration }
}
