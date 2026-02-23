// LogKit.swift
// LogKit
//
// Created by Iakov Senatov on 23.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared logging module for MiMiNavigator and all sub-packages.
//   Wraps SwiftyBeaver. Import LogKit anywhere → use log.debug / log.info / log.error.
//   Initialization (destinations, file path) is done once in the main app via LogKit.initialize().
//   Sub-packages only need `import LogKit` — they never call initialize() themselves.

import Foundation
@_exported import SwiftyBeaver

// MARK: - Global logger — the one and only `log` in the entire codebase
public let log = SwiftyBeaver.self

// MARK: - LogKit
public enum LogKit {

    // MARK: - Call once from AppDelegate / @main before any log.xxx() call
    public static func initialize(
        appSupportSubdir: String = "MiMiNavigator",
        logFileName: String = "MiMiNavigator.log",
        wipeOnLaunch: Bool = true
    ) {
        setupConsole()
        setupFile(appSupportSubdir: appSupportSubdir,
                  logFileName: logFileName,
                  wipeOnLaunch: wipeOnLaunch)
    }

    // MARK: - Console destination
    private static func setupConsole() {
        let console = ConsoleDestination()
        console.useTerminalColors = true
        console.useNSLog = false
        console.format = "$DHH:mm:ss$d $L $N.$F:$l $M"
        console.levelString.verbose  = "􀐯 VERBOSE"
        console.levelString.debug    = "􀌚 DEBUG"
        console.levelString.info     = "􀅴 INFO"
        console.levelString.warning  = "⚠️ WARNING"
        console.levelString.error    = "❗️ ERROR"
        console.levelString.critical = "🔥 CRITICAL"
        console.levelString.fault    = "💥 FAULT"
        log.addDestination(console)
    }

    // MARK: - File destination
    private static func setupFile(
        appSupportSubdir: String,
        logFileName: String,
        wipeOnLaunch: Bool
    ) {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return }

        let logsDir = base
            .appendingPathComponent(appSupportSubdir, isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let logFile = logsDir.appendingPathComponent(logFileName)
        if wipeOnLaunch {
            try? FileManager.default.removeItem(at: logFile)
        }

        let file = FileDestination()
        file.logFileURL = logFile
        log.addDestination(file)
        log.info("[LogKit] logging to: \(logFile.path)")
    }

    // MARK: - Log file URL (for settings/bug reports)
    public static func logFileURL(
        appSupportSubdir: String = "MiMiNavigator",
        logFileName: String = "MiMiNavigator.log"
    ) -> URL? {
        guard let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        return base
            .appendingPathComponent(appSupportSubdir, isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(logFileName)
    }
}
