// RevealInFinderService.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for "Show in Finder" / "Show in Enclosing Folder" functionality

import AppKit
import Foundation

// MARK: - Reveal In Finder Service
/// Opens Finder and reveals the file/folder
@MainActor
final class RevealInFinderService {
    
    static let shared = RevealInFinderService()
    private let workspace = NSWorkspace.shared
    
    private init() {
        log.debug("\(#function) RevealInFinderService initialized")
    }
    
    // MARK: - Reveal in Finder
    
    /// Reveals the file in Finder (selects it in its parent folder)
    func revealInFinder(_ fileURL: URL) {
        log.info("\(#function) file='\(fileURL.lastPathComponent)' path='\(fileURL.path)'")
        workspace.activateFileViewerSelecting([fileURL])
    }
    
    /// Reveals multiple files in Finder
    func revealInFinder(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else {
            log.warning("\(#function) called with empty array")
            return
        }
        log.info("\(#function) revealing \(fileURLs.count) items: \(fileURLs.map { $0.lastPathComponent })")
        workspace.activateFileViewerSelecting(fileURLs)
    }
    
    /// Opens the enclosing folder in Finder (without selecting)
    func openEnclosingFolder(_ fileURL: URL) {
        let parentDir = fileURL.deletingLastPathComponent()
        log.info("\(#function) file='\(fileURL.lastPathComponent)' opening folder='\(parentDir.path)'")
        workspace.open(parentDir)
    }
}
