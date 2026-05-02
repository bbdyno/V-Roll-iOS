//
//  CGSize+Aspect.swift
//  Core
//

import CoreGraphics

public extension CGSize {
    /// Returns the largest size that fits inside `bounds` while preserving
    /// aspect ratio. Used by the merge engine to fit each clip into a
    /// shared render canvas.
    func aspectFit(into bounds: CGSize) -> CGSize {
        guard width > 0, height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }
        let scale = min(bounds.width / width, bounds.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }
}
