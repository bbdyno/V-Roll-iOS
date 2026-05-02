//
//  Project.swift
//  V-Roll · Feature layer
//
//  User-facing features: video editor, AVFoundation-based merge engine,
//  sticker overlay rendering. Depends on Core only.
//

import ProjectDescription

let project = Project(
    name: "Feature",
    settings: .settings(
        base: [
            "SWIFT_VERSION": "5.9",
            "DEVELOPMENT_TEAM": "M79H9K226Y"
        ]
    ),
    targets: [
        .target(
            name: "Feature",
            destinations: .iOS,
            product: .framework,
            bundleId: "com.bbdyno.app.VRoll.feature",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["../../Targets/Feature/Sources/**"],
            resources: [
                "../../Targets/Feature/Resources/**/*.strings"
            ],
            dependencies: [
                .project(target: "Core", path: "../Core")
            ]
        )
    ]
)
