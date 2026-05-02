//
//  MediaPickers.swift
//  Feature
//
//  SwiftUI-native PhotosPicker wrappers. Both pickers stage their
//  results into `ScratchStorage` so the rest of the app deals only in
//  scratch URLs / `Data`, never in PHAsset identifiers.
//
//  PhotosPicker hands us `PhotosPickerItem` references — not bytes —
//  so loading is a separate async step via `loadTransferable`. We do
//  that work here in the wrapper to keep call sites linear.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Core

// MARK: - Video clip picker

public struct VideoClipPickerButton<Label: View>: View {
    public let maxSelectionCount: Int
    public let onPicked: ([URL]) async -> Void
    @ViewBuilder public let label: () -> Label

    @State private var selection: [PhotosPickerItem] = []

    public init(
        maxSelectionCount: Int = 10,
        onPicked: @escaping ([URL]) async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.maxSelectionCount = maxSelectionCount
        self.onPicked = onPicked
        self.label = label
    }

    public var body: some View {
        PhotosPicker(
            selection: $selection,
            maxSelectionCount: maxSelectionCount,
            matching: .videos,
            preferredItemEncoding: .current,
            photoLibrary: .shared(),
            label: label
        )
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                let urls = await Self.loadVideoURLs(from: items)
                await onPicked(urls)
                selection = []
            }
        }
    }

    private static func loadVideoURLs(from items: [PhotosPickerItem]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for item in items {
                group.addTask {
                    do {
                        guard let video = try await item.loadTransferable(type: PickedVideoFile.self) else {
                            return nil
                        }
                        return video.url
                    } catch {
                        AppLogger.shared.error("PhotosPicker video load failed: \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            var collected: [URL] = []
            for await url in group {
                if let url { collected.append(url) }
            }
            return collected
        }
    }
}

/// Transferable wrapper used by `loadTransferable`. PhotosPicker hands
/// us a temp file the system reclaims as soon as the closure returns —
/// we copy it into our scratch directory here so the URL stays valid
/// for the export pipeline.
private struct PickedVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = ScratchStorage.newExportURL(extension: ext)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PickedVideoFile(url: destination)
        }
    }
}

// MARK: - Sticker image picker

public struct StickerImagePickerButton<Label: View>: View {
    public let onPicked: (Data) async -> Void
    @ViewBuilder public let label: () -> Label

    @State private var selection: PhotosPickerItem?

    public init(
        onPicked: @escaping (Data) async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.onPicked = onPicked
        self.label = label
    }

    public var body: some View {
        PhotosPicker(
            selection: $selection,
            matching: .images,
            photoLibrary: .shared(),
            label: label
        )
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        await onPicked(data)
                    }
                } catch {
                    AppLogger.shared.error("PhotosPicker image load failed: \(error.localizedDescription)")
                }
                selection = nil
            }
        }
    }
}
