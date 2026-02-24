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
    
    /// Show Finder Get Info window centered on MiMi's main window.
    /// Window is created offscreen, positioned, then Finder is activated — no visible jump.
    @MainActor
    static func showGetInfo(for url: URL) {
        log.debug("[FinderIntegration] showGetInfo: \(url.path)")
        
        let escapedPath = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        
        // Get window position from NSApp (Cocoa) — reliable even during context menu
        var targetX = 500
        var targetY = 200
        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            let frame  = window.frame
            let screenH = NSScreen.screens.first?.frame.height ?? 1600
            // Place near top-right of main window
            targetX = Int(frame.maxX) - 360
            targetY = Int(screenH - frame.maxY) + 40
        }
        
        log.debug("[FinderIntegration] Get Info target=(\(targetX),\(targetY))")
        
        // Open Get Info fully expanded.
        // Finder info windows have no per-section AppleScript API —
        // 'set zoomed to true' is the only way to make Finder auto-expand all sections.
        // Position first, then zoom so the window expands downward from targetY.
        let script = """
        tell application "Finder"
            close every information window
            set infoWin to open information window of (POSIX file "\(escapedPath)" as alias)
            set collapsed of infoWin to false
            set position of infoWin to {\(targetX), \(targetY)}
            set zoomed of infoWin to true
        end tell
        tell application "Finder" to activate
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
