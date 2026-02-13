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
        
        let infoW = 340
        let infoH = 500
        
        // Get window position from NSApp (Cocoa) — reliable even during context menu
        var targetX = 500
        var targetY = 200
        if let window = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            let frame = window.frame
            let screenH = NSScreen.screens.first?.frame.height ?? 1600
            let topLeftX = Int(frame.origin.x)
            let topLeftY = Int(screenH - frame.origin.y - frame.height)
            targetX = topLeftX + (Int(frame.width) - infoW) / 2
            targetY = topLeftY + (Int(frame.height) - infoH) / 2
        }
        
        log.debug("[FinderIntegration] Get Info target=(\(targetX),\(targetY))")
        
        // Strategy: create window offscreen → position → activate (no visible jump)
        let script = """
        tell application "Finder"
            close every information window
            set infoWin to open information window of (POSIX file "\(escapedPath)" as alias)
            set zoomed of infoWin to false
            set collapsed of infoWin to false
            set bounds of infoWin to {\(targetX), \(targetY), \(targetX + infoW), \(targetY + infoH)}
            set current panel of infoWin to General Information panel
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
