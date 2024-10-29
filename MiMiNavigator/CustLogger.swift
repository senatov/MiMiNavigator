// CustomLogger.swift
//  MiMiNavigator

// Custom logging utility with Singleton pattern and multiple log levels
//  Created by Iakov Senatov on 16.10.24.
import Foundation
import os

final class CustomLogger {
    // Singleton instance
    static let shared = CustomLogger()

    // Private OS Logger instance
    private let logger: Logger

    // Private initializer to enforce Singleton
    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.senatov.MiMiNavigator"
        logger = Logger(subsystem: subsystem, category: "CustomLogger")
    }

    // Logging functions with different levels

    // MARK: - -

    func logInfo(_ message: String) {
        print("Executing logInfo") // Log for method tracking
        logger.info("\(message, privacy: .public)")
    }

    // MARK: - -

    func logDebug(_ message: String) {
        print("Executing logDebug") // Log for method tracking
        logger.debug("\(message, privacy: .public)")
    }

    // MARK: - -

    func logError(_ message: String) {
        print("Executing logError") // Log for method tracking
        logger.error("\(message, privacy: .public)")
    }

    // MARK: - -

    func logFault(_ message: String) {
        print("Executing logFault") // Log for method tracking
        logger.fault("\(message, privacy: .public)")
    }
}
