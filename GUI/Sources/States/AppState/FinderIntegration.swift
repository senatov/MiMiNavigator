// FinderIntegration.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Finder integration via AppleScript (Get Info, Reveal)

import AppKit
import Foundation

// MARK: - Finder Integration
/// Handles Finder-related operations via AppleScript
enum FinderIntegration {
    
    // MARK: - Get Info
    
    /// Show Finder Get Info window centered on main window
    static func showGetInfo(for url: URL) {
        log.debug("[FinderIntegration] showGetInfo: \(url.path)")
        
        guard let window = NSApp.mainWindow else {
            log.warning("[FinderIntegration] no main window, using simple Get Info")
            showGetInfoSimple(for: url)
            return
        }
        
        let frame = window.frame
        let centerX = Int(frame.midX)
        // Flip Y for AppleScript coordinates
        let centerY = Int(NSScreen.main!.frame.height - frame.midY)
        
        let infoWidth = 260
        let infoHeight = 400
        let posX = centerX - infoWidth / 2
        let posY = centerY - infoHeight / 2
        
        let script = """
        tell application "Finder"
            set infoWin to open information window of (POSIX file "\(url.path)" as alias)
            set bounds of infoWin to {\(posX), \(posY), \(posX + infoWidth), \(posY + infoHeight)}
            activate
        end tell
        """
        
        executeAppleScript(script, context: "Get Info for \(url.lastPathComponent)")
    }
    
    /// Simple Get Info without positioning
    static func showGetInfoSimple(for url: URL) {
        let script = """
        tell application "Finder"
            activate
            open information window of (POSIX file "\(url.path)" as alias)
        end tell
        """
        executeAppleScript(script, context: "Get Info (simple)")
    }
    
    // MARK: - Reveal in Finder
    
    /// Reveal file in Finder
    static func reveal(_ url: URL) {
        log.debug("[FinderIntegration] reveal: \(url.path)")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    /// Reveal log file or logs directory
    static func revealLogFile() {
        log.debug("[FinderIntegration] revealLogFile")
        
        let fm = FileManager.default
        let logsDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        let logFileURL = logsDir.appendingPathComponent("MiMiNavigator.log", isDirectory: false)
        
        if fm.fileExists(atPath: logFileURL.path) {
            log.debug("[FinderIntegration] revealing log: \(logFileURL.path)")
            NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
            return
        }
        
        // Create logs directory if needed
        if !fm.fileExists(atPath: logsDir.path) {
            do {
                try fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
                log.debug("[FinderIntegration] created Logs dir")
            } catch {
                log.error("[FinderIntegration] failed to create Logs: \(error.localizedDescription)")
            }
        }
        
        log.debug("[FinderIntegration] opening Logs dir")
        NSWorkspace.shared.activateFileViewerSelecting([logsDir])
    }
    
    // MARK: - Private
    
    private static func executeAppleScript(_ source: String, context: String) {
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            script.executeAndReturnError(&error)
            if let error = error {
                log.error("[FinderIntegration] AppleScript error (\(context)): \(error)")
            } else {
                log.info("[FinderIntegration] \(context) success")
            }
        }
    }
}
