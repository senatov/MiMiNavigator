    //
    //  CustomLogger.swift
    //  CustomLogger
    //
    //  Created by Iakov Senatov on 07.10.24.
    //


import Foundation
import os

class CustomLogger {
    private static let logger: Logger = {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.senatov.MiMiNavigator"
        return Logger(subsystem: subsystem, category: "UI")
    }()
    
    private static func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    private static func getCallerInfo(file: String = #file, function: String = #function, line: Int = #line) -> String {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        return "\(fileName):\(line) \(function)"
    }
    
    static func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timeStamp = getCurrentTime()
        let callerInfo = getCallerInfo(file: file, function: function, line: line)
        logger.info("INFO: \(message) | Time: \(timeStamp) | Called from: \(callerInfo)")
    }
    
    static func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timeStamp = getCurrentTime()
        let callerInfo = getCallerInfo(file: file, function: function, line: line)
        logger.error("ERROR: \(message) | Time: \(timeStamp) | Called from: \(callerInfo)")
    }
    
    static func logDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timeStamp = getCurrentTime()
        let callerInfo = getCallerInfo(file: file, function: function, line: line)
        logger.debug("DEBUG: \(message) | Time: \(timeStamp) | Called from: \(callerInfo)")
    }
}
