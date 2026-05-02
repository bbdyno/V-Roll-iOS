//
//  AppContainer.swift
//  V-Roll
//
//  Lightweight composition root. Holds the long-lived services that
//  features pull from the SwiftUI environment. Keeping this tiny and
//  hand-wired avoids dragging in a DI library before we need one.
//

import Foundation
import Observation
import Core
import Feature

@Observable
public final class AppContainer {
    public let videoEditorEngine: VideoEditorEngine
    public let stickerLibrary: StickerLibrary
    public let mediaLibrary: MediaLibraryService

    public init(
        videoEditorEngine: VideoEditorEngine,
        stickerLibrary: StickerLibrary,
        mediaLibrary: MediaLibraryService
    ) {
        self.videoEditorEngine = videoEditorEngine
        self.stickerLibrary = stickerLibrary
        self.mediaLibrary = mediaLibrary
    }

    public static func live() -> AppContainer {
        AppContainer(
            videoEditorEngine: AVFoundationVideoEditorEngine(),
            stickerLibrary: StickerLibrary.bundled(),
            mediaLibrary: PhotosMediaLibraryService()
        )
    }
}
