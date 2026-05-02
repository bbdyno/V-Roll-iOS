//
//  PlayerLayerView.swift
//  Feature
//
//  Direct AVPlayerLayer wrapper. We avoid `VideoPlayer` (SwiftUI) and
//  `AVPlayerViewController` because both render their own playback
//  chrome — we want a clean surface so the custom transport bar below
//  is the only set of controls the user ever sees.
//

import SwiftUI
import AVFoundation
import UIKit

public struct PlayerLayerView: UIViewRepresentable {
    public let player: AVPlayer
    public var videoGravity: AVLayerVideoGravity

    public init(player: AVPlayer, videoGravity: AVLayerVideoGravity = .resizeAspect) {
        self.player = player
        self.videoGravity = videoGravity
    }

    public func makeUIView(context: Context) -> Container {
        let view = Container()
        view.backgroundColor = .black
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        return view
    }

    public func updateUIView(_ uiView: Container, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        uiView.playerLayer.videoGravity = videoGravity
    }

    public final class Container: UIView {
        public override class var layerClass: AnyClass { AVPlayerLayer.self }
        public var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
