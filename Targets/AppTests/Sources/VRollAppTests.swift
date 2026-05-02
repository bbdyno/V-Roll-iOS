//
//  VRollAppTests.swift
//  V-Roll
//

import XCTest
@testable import VRoll
@testable import Core
@testable import Feature

final class VRollAppTests: XCTestCase {
    func test_appContainer_live_buildsAllServices() {
        let container = AppContainer.live()
        XCTAssertNotNil(container.videoEditorEngine)
        XCTAssertNotNil(container.stickerLibrary)
        XCTAssertNotNil(container.mediaLibrary)
    }

    func test_videoMergePlan_emptyClipsThrows() {
        let engine = AVFoundationVideoEditorEngine()
        let plan = VideoMergePlan(clips: [], stickers: [])
        XCTAssertThrowsError(try engine.validate(plan)) { error in
            XCTAssertEqual(error as? VideoEditorError, .emptyPlan)
        }
    }
}
