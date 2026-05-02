//
//  StickerPickerView.swift
//  Feature
//

import SwiftUI
import Core

struct StickerPickerView: View {
    let library: StickerLibrary
    let onPick: (Sticker) -> Void
    let onPickImageData: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 80), spacing: VRollTheme.Spacing.m)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: VRollTheme.Spacing.m) {
                    ForEach(library.stickers) { sticker in
                        Button {
                            onPick(sticker)
                            dismiss()
                        } label: {
                            stickerTile(sticker)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(VRollTheme.Spacing.m)
            }
            .navigationTitle(FeatureStrings.Sticker.Picker.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    StickerImagePickerButton { data in
                        onPickImageData(data)
                        dismiss()
                    } label: {
                        Label(FeatureStrings.Sticker.Picker.From.photos, systemImage: "photo.on.rectangle.angled")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(FeatureStrings.Common.close) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func stickerTile(_ sticker: Sticker) -> some View {
        VStack(spacing: VRollTheme.Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: VRollTheme.Radius.medium, style: .continuous)
                    .fill(VRollTheme.surface)
                    .frame(width: 80, height: 80)
                stickerGlyph(sticker)
            }
            Text(sticker.displayName)
                .font(.caption2)
                .foregroundStyle(VRollTheme.muted)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func stickerGlyph(_ sticker: Sticker) -> some View {
        switch sticker.kind {
        case .emoji(let value), .text(let value):
            Text(value)
                .font(.system(size: 36))
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(VRollTheme.accent)
        case .image(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            }
        }
    }
}
