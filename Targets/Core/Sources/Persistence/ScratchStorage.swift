//
//  ScratchStorage.swift
//  Core
//
//  Provides a per-launch scratch directory the merge engine writes
//  intermediate exports into. Cleared at app start so we never ship
//  stale exports to users.
//

import Foundation

public enum ScratchStorage {
    public static let directory: URL = {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("VRoll", isDirectory: true)
            .appendingPathComponent("Scratch", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    public static func newExportURL(extension ext: String = "mp4") -> URL {
        directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    public static func purge() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents {
            try? fm.removeItem(at: url)
        }
    }
}
