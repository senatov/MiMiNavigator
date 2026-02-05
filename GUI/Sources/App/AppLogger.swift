// AppLogger.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 24.06.2025.
// Refactored: 27.01.2026
// Copyright © 2025-2026 Senatov. All rights reserved.
// Description: Application-wide logging configuration using SwiftyBeaver

import AppKit
import Foundation
import SwiftyBeaver

// MARK: - App Logger
/// Centralized logging configuration.
/// Initializes console and file destinations for SwiftyBeaver.
/// Access via `log.info()`, `log.debug()`, `log.error()`, etc.
enum AppLogger {
    static let log = SwiftyBeaver.self

    // MARK: - Initialize logging system
    static func initialize() {
        setupConsoleDestination()
        setupFileDestination()
    }
    
    // MARK: - Setup console output
    private static func setupConsoleDestination() {
        let console = ConsoleDestination()
        console.useTerminalColors = true
        console.useNSLog = false
        console.format = "$DHH:mm:ss$d $L $N.$F:$l $M"
        
        // Configure level icons
        console.levelString.verbose = levelIcon(for: .verbose) + " VERBOSE"
        console.levelString.debug = levelIcon(for: .debug) + " DEBUG"
        console.levelString.info = levelIcon(for: .info) + " INFO"
        console.levelString.warning = levelIcon(for: .warning) + " WARNING"
        console.levelString.error = levelIcon(for: .error) + " ERROR"
        console.levelString.critical = levelIcon(for: .critical) + " CRITICAL"
        console.levelString.fault = levelIcon(for: .fault) + " FAULT"
        
        log.addDestination(console)
    }
    
    // MARK: - Setup file output
    private static func setupFileDestination() {
        guard let containerURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else {
            return
        }
        
        let logsDir = containerURL.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        let logFile = logsDir.appendingPathComponent("MiMiNavigator.log")
        let file = FileDestination()
        file.logFileURL = logFile
        log.addDestination(file)
        log.info("Logging to: \(logFile.path)")
    }
    
    // MARK: - Level icons
    private static func levelIcon(for level: SwiftyBeaver.Level) -> String {
        switch level {
        case .verbose: return "􀐯"
        case .debug: return "􀌚"
        case .info: return "􀅴"
        case .warning: return "⚠️"
        case .error: return "❗️"
        case .critical: return "🔥"
        case .fault: return "💥"
        }
    }
    
    // MARK: - Get log file URL
    static var logFileURL: URL? {
        guard let containerURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else {
            return nil
        }
        return containerURL
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MiMiNavigator.log")
    }
}

// MARK: - Global Logger Reference
/// Global logger instance - use `log.info()`, `log.debug()`, etc.
let log = AppLogger.log

