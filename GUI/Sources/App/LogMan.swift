//
//  LogMan.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 24.06.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Foundation
import SwiftyBeaver

// MARK: -
enum LogMan {
    static let log = SwiftyBeaver.self

    // MARK: -
    static func initializeLogging() {
        let console = ConsoleDestination()
        console.useTerminalColors = true
        console.useNSLog = false
        console.format = "$DHH:mm:ss$d $L $N.$F:$l $M"
        // Уровни с иконками
        func getLevelIcon(for level: SwiftyBeaver.Level) -> String {
            switch level {
            case .verbose: return "🔮"
            case .debug: return "☘️"
            case .info: return "🔹"
            case .warning: return "🔸"
            case .error: return "💢"
            case .critical: return "💀"
            case .fault: return "👻"
            }
        }
        console.levelString.verbose = getLevelIcon(for: .verbose) + " VERBOSE"
        console.levelString.debug = getLevelIcon(for: .debug) + " DEBUG"
        console.levelString.info = getLevelIcon(for: .info) + " INFO"
        console.levelString.warning = getLevelIcon(for: .warning) + " WARNING"
        console.levelString.error = getLevelIcon(for: .error) + " ERROR"
        console.levelString.critical =
            getLevelIcon(for: .critical) + " CRITICAL"
        console.levelString.fault = getLevelIcon(for: .fault) + " FAULT"
        log.addDestination(console)
        setupLogging()
    }

    // MARK: -
    private static func setupLogging() {
        let containerURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let logsDir = containerURL.appendingPathComponent(
            "Logs",
            isDirectory: true
        )
        // Создать Logs/ при необходимости
        try? FileManager.default.createDirectory(
            at: logsDir,
            withIntermediateDirectories: true
        )
        let logFile = logsDir.appendingPathComponent("MiMiNavigator.log")
        let file = FileDestination()
        file.logFileURL = logFile
        log.addDestination(file)
        log.info("Logging to: \(logFile.path)")
    }
}
