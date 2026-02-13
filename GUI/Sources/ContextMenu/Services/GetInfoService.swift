// GetInfoService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
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
    /// Delegates to FinderIntegration for proper positioning near MiMi window
    func showGetInfo(for fileURL: URL) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)' path='\(fileURL.path)'")
        FinderIntegration.showGetInfo(for: fileURL)
    }
    
    /// Opens Get Info for multiple files (positioned near MiMi window)
    func showGetInfo(for fileURLs: [URL]) {
        log.debug(#function)
        guard !fileURLs.isEmpty else {
            log.warning("\(#function) called with empty array")
            return
        }
        
        // For single file, use positioned variant
        if fileURLs.count == 1 {
            showGetInfo(for: fileURLs[0])
            return
        }
        
        // For multiple files, open all (Finder will cascade them)
        log.info("\(#function) showing Get Info for \(fileURLs.count) items")
        for url in fileURLs {
            FinderIntegration.showGetInfo(for: url)
        }
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
