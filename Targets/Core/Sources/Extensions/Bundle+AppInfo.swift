//
//  Bundle+AppInfo.swift
//  Core
//

import Foundation

public extension Bundle {
    var appBuildLabel: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
