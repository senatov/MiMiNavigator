    // CustomLogger.swift
    // Custom logging utility with Singleton pattern and multiple log levels
    // Created by Iakov Senatov

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
        self.logger = Logger(subsystem: subsystem, category: "CustomLogger")
    }
    
        // Logging functions with different levels
    func logInfo(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
    
    func logDebug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
    
    func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
    
    func logFault(_ message: String) {
        logger.fault("\(message, privacy: .public)")
    }
}
