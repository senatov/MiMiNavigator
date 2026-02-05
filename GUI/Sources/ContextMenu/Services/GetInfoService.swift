// GetInfoService.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for "Get Info" functionality - opens Finder's native info panel

import AppKit
import Foundation

// MARK: - Get Info Service
/// Opens Finder's native "Get Info" window for files and folders
@MainActor
final class GetInfoService {
    
    static let shared = GetInfoService()
    
    private init() {
        log.debug("\(#function) GetInfoService initialized")
    }
    
    // MARK: - Show Get Info Panel
    
    /// Opens Finder's native Get Info window for the specified file/folder
    /// This is the standard macOS behavior (⌘I in Finder)
    func showGetInfo(for fileURL: URL) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)' path='\(fileURL.path)'")
        // Method 1: Use NSWorkspace activation with Finder
        let script = """
            tell application "Finder"
                activate
                open information window of (POSIX file "\(fileURL.path)" as alias)
            end tell
            """
        executeAppleScript(script, description: "Get Info for '\(fileURL.lastPathComponent)'")
    }
    
    /// Opens Get Info for multiple files
    func showGetInfo(for fileURLs: [URL]) {
        log.debug(#function)
        guard !fileURLs.isEmpty else {
            log.warning("\(#function) called with empty array")
            return
        }
        
        if fileURLs.count == 1 {
            showGetInfo(for: fileURLs[0])
            return
        }
        
        log.info("\(#function) showing Get Info for \(fileURLs.count) items")
        
        let pathList = fileURLs.map { "POSIX file \"\($0.path)\" as alias" }.joined(separator: ", ")
        let script = """
            tell application "Finder"
                activate
                open information window of {\(pathList)}
            end tell
            """
        
        executeAppleScript(script, description: "Get Info for \(fileURLs.count) items")
    }
    
    // MARK: - Private Helpers
    
    private func executeAppleScript(_ source: String, description: String) {
        log.debug("\(#function) executing: \(description)")
        DispatchQueue.global(qos: .userInitiated).async {
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                
                if let error = error {
                    log.error("\(#function) AppleScript FAILED: \(error)")
                } else {
                    log.debug("\(#function) AppleScript SUCCESS: \(description)")
                }
            } else {
                log.error("\(#function) failed to create NSAppleScript")
            }
        }
    }
}
