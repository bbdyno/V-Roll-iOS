//
//  Project.swift
//  V-Roll · App layer
//
//  Top-level iOS application target. Wires the Core and Feature modules
//  together and ships the user-facing entry point.
//

import ProjectDescription

let appVersion = "1.0.0"
let appBuildNumber = "2026.05.02.1"
let developmentTeam = "M79H9K226Y"

let baseSettings: SettingsDictionary = [
    "SWIFT_VERSION": "5.9",
    "DEVELOPMENT_TEAM": .string(developmentTeam),
    "MARKETING_VERSION": .string(appVersion),
    "CURRENT_PROJECT_VERSION": .string(appBuildNumber),
    "CODE_SIGN_STYLE": "Automatic"
]

let project = Project(
    name: "App",
    settings: .settings(base: baseSettings),
    targets: [
        .target(
            name: "VRoll",
            destinations: .iOS,
            product: .app,
            bundleId: "com.bbdyno.app.VRoll",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "V-Roll",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "CFBundleDevelopmentRegion": "en",
                "CFBundleLocalizations": ["en", "ko", "ja"],
                "UILaunchScreen": [
                    "UIColorName": "AccentColor"
                ],
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false
                ],
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationPortrait"
                ],
                "ITSAppUsesNonExemptEncryption": false,
                "NSPhotoLibraryUsageDescription": "V-Roll needs access to your photo library to import videos for editing.",
                "NSPhotoLibraryAddUsageDescription": "V-Roll saves merged videos back to your photo library.",
                "NSCameraUsageDescription": "V-Roll uses the camera so you can capture clips to edit.",
                "NSMicrophoneUsageDescription": "V-Roll records audio together with the video clips you capture."
            ]),
            sources: ["../../Targets/App/Sources/**"],
            resources: [
                "../../Targets/App/Resources/Assets.xcassets",
                "../../Targets/App/Resources/**/*.strings"
            ],
            entitlements: "../../Targets/App/App.entitlements",
            dependencies: [
                .project(target: "Core", path: "../Core"),
                .project(target: "Feature", path: "../Feature")
            ]
        ),
        .target(
            name: "AppTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.bbdyno.app.VRoll.tests",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .default,
            sources: ["../../Targets/AppTests/Sources/**"],
            dependencies: [
                .target(name: "VRoll"),
                .project(target: "Core", path: "../Core"),
                .project(target: "Feature", path: "../Feature")
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "VRoll",
            shared: true,
            buildAction: .buildAction(targets: ["VRoll"]),
            testAction: .targets(["AppTests"], configuration: .debug),
            runAction: .runAction(configuration: .debug, executable: "VRoll")
        )
    ]
)
