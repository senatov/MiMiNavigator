// ConsoleCurrPath.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.10.24.
//  Copyright © 2024 Senatov. All rights reserved.

import AppKit
import Foundation

// MARK: - Helper to open Terminal at specified directory
final class ConsoleCurrPath {
    
    @discardableResult
    static func open(in directory: String) -> Bool {
        let dir = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dir.isEmpty else {
            log.error("Empty directory string provided")
            return false
        }
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir, isDirectory: &isDir), isDir.boolValue else {
            log.error("Directory not found: \(dir)")
            return false
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Terminal", dir]
        
        do {
            try task.run()
            log.debug("Terminal opened for: \(dir)")
            return true
        } catch {
            log.error("Failed to open Terminal: \(error.localizedDescription)")
            return false
        }
    }
}
