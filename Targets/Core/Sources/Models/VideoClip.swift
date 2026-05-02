//
//  VideoClip.swift
//  Core
//

import Foundation
import CoreMedia

public struct VideoClip: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let duration: CMTime
    public let pixelSize: CGSize

    /// User-selected sub-range to keep when this clip is rendered into
    /// the merge composition. Defaults to `[.zero, duration]`. Stored
    /// here (not on a separate edits table) so reorder, remove and
    /// trim survive a single source-of-truth refactor.
    public var trimRange: CMTimeRange

    public init(
        id: UUID = UUID(),
        url: URL,
        duration: CMTime,
        pixelSize: CGSize,
        trimRange: CMTimeRange? = nil
    ) {
        self.id = id
        self.url = url
        self.duration = duration
        self.pixelSize = pixelSize
        self.trimRange = trimRange ?? CMTimeRange(start: .zero, duration: duration)
    }

    /// Duration that actually contributes to the merged timeline —
    /// used by the engine cursor and by sticker timing UI.
    public var effectiveDuration: CMTime {
        trimRange.duration
    }
}
