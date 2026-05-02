//
//  Tuist.swift
//  V-Roll
//
//  Tuist workspace configuration. Resource synthesizers are enabled by
//  default in Tuist 4 — that is what powers `Strings.someKey` accessors
//  generated from each target's `*.lproj/Localizable.strings`.
//

import ProjectDescription

let config = Config(
    compatibleXcodeVersions: .all,
    swiftVersion: "5.9"
)
