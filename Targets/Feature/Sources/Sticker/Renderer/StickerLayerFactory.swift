//
//  StickerLayerFactory.swift
//  Feature
//
//  Builds the CALayer tree that AVVideoCompositionCoreAnimationTool
//  composites on top of the merged video. AVFoundation rasterizes the
//  layers into the video frames during export, so this is what makes
//  the stickers actually bake in.
//
//  Two AVFoundation gotchas to be aware of:
//   • The animation tool runs CoreAnimation in a *flipped* coordinate
//     space (origin bottom-left). We translate Y to compensate so SwiftUI
//     callers can keep thinking top-left.
//   • A CABasicAnimation that drives layer opacity needs `beginTime` set
//     to `AVCoreAnimationBeginTimeAtZero`, not 0. Using 0 makes
//     CoreAnimation treat it as "start when layer is added" which fires
//     during export setup and the sticker never appears.
//

import Foundation
import AVFoundation
import QuartzCore
import UIKit
import CoreText
import CoreMedia

public enum StickerLayerFactory {
    public static func makeLayer(
        from placement: StickerLayer,
        canvasSize: CGSize,
        totalDuration: CMTime
    ) -> CALayer {
        let layer = baseLayer(for: placement.sticker, sizePoints: placement.sizePoints)
        let pointSize = CGSize(width: placement.sizePoints, height: placement.sizePoints)

        let centerX = placement.normalizedCenter.x * canvasSize.width
        let topLeftY = placement.normalizedCenter.y * canvasSize.height
        let flippedY = canvasSize.height - topLeftY - pointSize.height / 2

        layer.frame = CGRect(
            x: centerX - pointSize.width / 2,
            y: flippedY,
            width: pointSize.width,
            height: pointSize.height
        )
        layer.transform = CATransform3DMakeRotation(placement.rotation, 0, 0, 1)

        attachVisibilityWindow(
            to: layer,
            range: placement.timeRange,
            totalDuration: totalDuration
        )

        return layer
    }

    private static func baseLayer(for sticker: Sticker, sizePoints: CGFloat) -> CALayer {
        switch sticker.kind {
        case .emoji(let value), .text(let value):
            return makeTextLayer(value: value, sizePoints: sizePoints)
        case .systemImage(let name):
            return makeSystemImageLayer(name: name, sizePoints: sizePoints)
        case .image(let data):
            return makeImageLayer(data: data)
        }
    }

    private static func makeTextLayer(value: String, sizePoints: CGFloat) -> CATextLayer {
        let layer = CATextLayer()
        layer.string = value
        layer.fontSize = sizePoints * 0.7
        layer.alignmentMode = .center
        layer.contentsScale = UIScreen.main.scale
        layer.foregroundColor = UIColor.white.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        return layer
    }

    private static func makeSystemImageLayer(name: String, sizePoints: CGFloat) -> CALayer {
        let layer = CALayer()
        let configuration = UIImage.SymbolConfiguration(pointSize: sizePoints * 0.8, weight: .semibold)
        let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        layer.contents = image?.cgImage
        layer.contentsGravity = .resizeAspect
        return layer
    }

    private static func makeImageLayer(data: Data) -> CALayer {
        let layer = CALayer()
        layer.contents = UIImage(data: data)?.cgImage
        layer.contentsGravity = .resizeAspect
        layer.contentsScale = UIScreen.main.scale
        // Soft drop-shadow so user-picked PNGs with transparent backgrounds
        // still read against busy footage.
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
        return layer
    }

    /// Drives the layer's opacity to 1 only inside `range`. We attach
    /// two CABasicAnimations:
    ///   • `appear`: opacity 0 → 1 at `range.start`
    ///   • `disappear`: opacity 1 → 0 at `range.end`
    /// `AVCoreAnimationBeginTimeAtZero` is the magic value AVFoundation
    /// uses as the export-pipeline epoch — passing literal 0 makes
    /// CoreAnimation interpret it as "fire when added", which during
    /// export means the animation has already finished by the time the
    /// first frame is rendered.
    private static func attachVisibilityWindow(
        to layer: CALayer,
        range: CMTimeRange,
        totalDuration: CMTime
    ) {
        let start = max(0, CMTimeGetSeconds(range.start))
        let end = min(CMTimeGetSeconds(totalDuration), start + CMTimeGetSeconds(range.duration))
        guard end > start else {
            layer.isHidden = true
            return
        }

        layer.opacity = 0
        let appear = CABasicAnimation(keyPath: "opacity")
        appear.fromValue = 0
        appear.toValue = 1
        appear.beginTime = AVCoreAnimationBeginTimeAtZero + start
        appear.duration = 0.001
        appear.fillMode = .forwards
        appear.isRemovedOnCompletion = false
        layer.add(appear, forKey: "appear")

        let disappear = CABasicAnimation(keyPath: "opacity")
        disappear.fromValue = 1
        disappear.toValue = 0
        disappear.beginTime = AVCoreAnimationBeginTimeAtZero + end
        disappear.duration = 0.001
        disappear.fillMode = .forwards
        disappear.isRemovedOnCompletion = false
        layer.add(disappear, forKey: "disappear")
    }
}
