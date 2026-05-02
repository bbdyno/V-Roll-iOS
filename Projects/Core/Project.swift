//
//  Project.swift
//  V-Roll · Core layer
//
//  Shared infrastructure: logging, theme, models, persistence helpers.
//  No SwiftUI screens here — UI lives in Feature.
//

import ProjectDescription

let project = Project(
    name: "Core",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "DEVELOPMENT_TEAM": "M79H9K226Y"
        ]
    ),
    targets: [
        .target(
            name: "Core",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.bbdyno.app.VRoll.core",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["../../Targets/Core/Sources/**"],
            resources: [
                "../../Targets/Core/Resources/**/*.strings"
            ]
        )
    ]
)
