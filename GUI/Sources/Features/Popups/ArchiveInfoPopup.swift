// ArchiveInfoPopup.swift
// MiMiNavigator
//
// Created by Claude on 18.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Yellow HUD popup showing archive operation details. Click to dismiss.

import AppKit
import Foundation

// MARK: - Archive Info Popup Controller

@MainActor
final class ArchiveInfoPopupController: InfoPopupController {
    
    static let shared = ArchiveInfoPopupController()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Show Archive Created Info
    
    /// Shows a yellow popup with archive operation details, centered on screen
    func showArchiveCreated(
        archiveName: String,
        destination: URL,
        fileCount: Int,
        format: ArchiveFormat,
        compressionLevel: CompressionLevel,
        encrypted: Bool
    ) {
        let content = buildArchiveContent(
            archiveName: archiveName,
            destination: destination,
            fileCount: fileCount,
            format: format,
            compressionLevel: compressionLevel,
            encrypted: encrypted
        )
        
        // Show centered on main window
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let windowFrame = window.frame
        let anchorFrame = CGRect(
            x: windowFrame.width / 2,
            y: windowFrame.height / 2,
            width: 1,
            height: 1
        )
        
        show(content: content, anchorFrame: anchorFrame, width: 380)
    }
    
    // MARK: - Build Content
    
    private func buildArchiveContent(
        archiveName: String,
        destination: URL,
        fileCount: Int,
        format: ArchiveFormat,
        compressionLevel: CompressionLevel,
        encrypted: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Title with checkmark
        result.appendHUD(
            "✓ Archive Created\n\n",
            font: NSFont.systemFont(ofSize: 14, weight: .light),
            color: NSColor(calibratedRed: 0.1, green: 0.5, blue: 0.2, alpha: 1.0)
        )
        
        // Archive name
        result.appendField(label: "Name", value: archiveName)
        
        // Destination path
        result.appendField(label: "Location", value: destination.path)
        
        // Files count
        let filesText = fileCount == 1 ? "1 file" : "\(fileCount) files"
        result.appendField(label: "Files", value: filesText)
        
        // Format
        result.appendField(label: "Format", value: format.displayName)
        
        // Compression
        result.appendField(label: "Compression", value: compressionLevel.displayName)
        
        // Encrypted
        if encrypted {
            result.appendField(label: "Encrypted", value: "🔒 Yes")
        }
        
        // Footer
        result.appendHUD(
            "\nClick anywhere to dismiss",
            font: NSFont.systemFont(ofSize: 10, weight: .light),
            color: NSColor.secondaryLabelColor
        )
        
        return result
    }
}
