# V-Roll

A SwiftUI iOS app for stitching short clips and stamping stickers on top — built straight on `AVFoundation` with **no third-party dependencies**.

## Stack

- **Tuist 4.x** for project generation (`Tuist.swift`, `Workspace.swift`, layer-scoped `Project.swift`).
- **SwiftUI** + the `@Observable` Observation framework.
- **AVFoundation** (`AVMutableComposition`, `AVAssetExportSession`, `AVVideoCompositionCoreAnimationTool`).
- **PhotosUI** (`PHPickerViewController`) for clip import.
- **TuistStrings** — Tuist's built-in resource synthesizer turns each target's `*.lproj/Localizable.strings` into typed `Strings.someKey` accessors.

## Layers

```
Projects/
├── App/        # iOS app target (VRoll). Wires DI, hosts root scene.
├── Core/       # Reusable infrastructure: logging, theme, models, storage.
└── Feature/    # User features: editor view/VM, AVFoundation merge engine, sticker rendering.
```

```
Targets/
├── App/
│   ├── Sources/{App,Root,DI,Scene}
│   └── Resources/{Assets.xcassets, en.lproj, ko.lproj, ja.lproj}
├── Core/
│   ├── Sources/{Logging,Theme,Extensions,Models,Services,Persistence}
│   └── Resources/{en.lproj, ko.lproj, ja.lproj}
├── Feature/
│   ├── Sources/{VideoEditor/{View,ViewModel,Components}, VideoMerge/{Engine,Model}, Sticker/{View,ViewModel,Model,Renderer}, Picker, Common}
│   └── Resources/{en.lproj, ko.lproj, ja.lproj}
└── AppTests/
```

Dependency direction is one-way: **App → Feature → Core**. Core depends on nothing in this workspace.

## Generate & open

```bash
cd V-Roll
tuist install     # noop if no SPM packages, kept for future use
tuist generate
open V-Roll.xcworkspace
```

## TuistStrings

Tuist 4 enables resource synthesizers by default. Drop a `*.strings` file inside any `*.lproj` directory listed in a target's `resources:` array and Tuist generates a per-target `Strings` enum with one static property per key. Example call sites:

```swift
Text(Strings.appTitle)              // App target
Text(Strings.commonRetry)           // Core target
Text(Strings.editorMerge)           // Feature target
```

Add a new key by writing it once into every `*.lproj/Localizable.strings`, then re-run `tuist generate` so the synthesized `Strings.swift` picks it up.

## Paid-app friendly

- Bundle ID `com.bbdyno.app.VRoll` is wired up with automatic signing via `DEVELOPMENT_TEAM=M79H9K226Y` — replace with your own team before archiving.
- `ITSAppUsesNonExemptEncryption = false` set up front so App Store Connect doesn't block first-time submission.
- All required usage descriptions (`NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`, `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`) are declared in the App's Info.plist.
- Strict layer separation keeps the merge engine swappable — useful if you later want to A/B export pipelines without touching the editor UI.
