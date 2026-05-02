//
//  MediaLibraryService.swift
//  Core
//

import Foundation
import Photos

public enum MediaLibraryError: Error {
    case permissionDenied
    case saveFailed(underlying: Error?)
}

public protocol MediaLibraryService: Sendable {
    func requestAuthorization() async -> PHAuthorizationStatus
    func saveVideoToLibrary(at url: URL) async throws
}

public struct PhotosMediaLibraryService: MediaLibraryService {
    public init() {}

    public func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    public func saveVideoToLibrary(at url: URL) async throws {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            throw MediaLibraryError.permissionDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
        }
    }
}
