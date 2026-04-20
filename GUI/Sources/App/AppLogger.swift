// AppLogger.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.06.2025.
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: App-side logging bootstrap. All configuration lives in LogKit.
//   Import LogKit anywhere -> use log.debug / log.info / log.error.
//   GUI module re-exports global `log = SwiftyBeaver.self` for all source files.

import Foundation
import LogKit

// MARK: - Global logger re-export for GUI module
// All GUI source files use `log.debug(...)` without any import — picked up from here.
// SwiftyBeaver is re-exported from LogKit via @_exported, so SwiftyBeaver.self is accessible.
let log = SwiftyBeaver.self

// MARK: - AppLogger
/// Thin bootstrap wrapper — initializes LogKit once at app startup.
/// All actual logger config (console, file, icons) is in LogKit/LogKit.swift.
enum AppLogger {
    private static let defaultLogFileName = "MiMiNavigator.log"
    private static let defaultAppSupportSubdir = "MiMiNavigator"

    // MARK: - Call from @main init()
    static func initialize() {
        LogKit.initialize(
            appSupportSubdir: defaultAppSupportSubdir,
            logFileName: defaultLogFileName,
            wipeOnLaunch: false,
            rotationPolicy: .init(
                maxFileSizeBytes: 50 * 1024 * 1024,
                uncompressedBackupCount: 3
            )
        )
    }

    // MARK: - Log file URL (for settings / bug reports)
    static var logFileURL: URL? {
        LogKit.logFileURL(
            appSupportSubdir: defaultAppSupportSubdir,
            logFileName: defaultLogFileName
        )
    }

    static var tmpLogFileURL: URL {
        URL(fileURLWithPath: "/tmp").appendingPathComponent(defaultLogFileName)
    }

    static var protectedLogFileURLs: [URL] {
        [logFileURL, tmpLogFileURL]
            .compactMap { $0 }
            .map { $0.resolvingSymlinksInPath().standardizedFileURL }
    }

    static func isProtectedLogFile(_ url: URL) -> Bool {
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL
        return protectedLogFileURLs.contains(candidate)
    }
}
