//
//  VRollApp.swift
//  V-Roll
//

import SwiftUI
import Core
import Feature

@main
struct VRollApp: App {
    @State private var container = AppContainer.live()

    init() {
        AppLogger.shared.info("V-Roll launched · build \(Bundle.main.appBuildLabel)")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .tint(VRollTheme.accent)
                .preferredColorScheme(.dark)
        }
    }
}
