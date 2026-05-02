//
//  AppLogger.swift
//  Core
//

import Foundation
import os

public final class AppLogger {
    public static let shared = AppLogger()

    private let logger: Logger

    private init() {
        self.logger = Logger(subsystem: "com.bbdyno.app.VRoll", category: "app")
    }

    public func debug(_ message: @autoclosure () -> String) {
        let value = message()
        logger.debug("\(value, privacy: .public)")
    }

    public func info(_ message: @autoclosure () -> String) {
        let value = message()
        logger.info("\(value, privacy: .public)")
    }

    public func warn(_ message: @autoclosure () -> String) {
        let value = message()
        logger.warning("\(value, privacy: .public)")
    }

    public func error(_ message: @autoclosure () -> String) {
        let value = message()
        logger.error("\(value, privacy: .public)")
    }
}
