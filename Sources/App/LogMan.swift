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
        let cn = ConsoleDestination()
        cn.useTerminalColors = true
        cn.useNSLog = false
        cn.format = "$DHH:mm:ss$d $L $N.$F:$l $M"
        // Уровни с иконками
        func getLevelIcon(for level: SwiftyBeaver.Level) -> String {
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
        cn.levelString.verbose = getLevelIcon(for: .verbose) + " VERBOSE"
        cn.levelString.debug = getLevelIcon(for: .debug) + " DEBUG"
        cn.levelString.info = getLevelIcon(for: .info) + " INFO"
        cn.levelString.warning = getLevelIcon(for: .warning) + " WARNING"
        cn.levelString.error = getLevelIcon(for: .error) + " ERROR"
        cn.levelString.critical = getLevelIcon(for: .critical) + " CRITICAL"
        cn.levelString.fault = getLevelIcon(for: .fault) + " FAULT"
        log.addDestination(cn)
        setupLogging()
    }

    // MARK: -
    private static func setupLogging() {
        let containerURL = FileManager.default
            .urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )
            .first!
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
