// PathFormatting.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Path formatting utilities for display in dialogs and UI

import Foundation
import FileModelKit

enum PathFormatting {
    
    // MARK: - Path display limit
    private static let maxPathDisplayLength = 256
    
    // MARK: - Truncate path macOS style (keeps start and end, adds … in middle)
    static func truncatePath(_ path: String, maxLength: Int = maxPathDisplayLength) -> String {
        guard path.count > maxLength else { return path }
        
        let url = URL(fileURLWithPath: path)
        let components = url.pathComponents
        
        // If very few components, just truncate with ellipsis
        guard components.count > 3 else {
            let half = (maxLength - 3) / 2
            let start = path.prefix(half)
            let end = path.suffix(half)
            return "\(start)…\(end)"
        }
      
        // Always include root and first component
        let root = components[0] == "/" ? "/" : components[0] + "/"
        let first = components.count > 1 ? components[1] : ""
        let prefix = root + first
        
        // Always include last two components
        let lastTwo = components.suffix(2).joined(separator: "/")
        
        // Check if we can fit prefix + … + lastTwo
        if prefix.count + 1 + lastTwo.count <= maxLength {
            return prefix + "/…/" + lastTwo
        }
        
        // If still too long, truncate the filename part
        let half = (maxLength - 3) / 2
        let start = path.prefix(half)
        let end = path.suffix(half)
        return "\(start)…\(end)"
    }
    
    // MARK: - Format path for display in dialogs (replace home with ~)
    static func displayPath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        var displayable = path
        if displayable.hasPrefix(homePath) {
            displayable = "~" + displayable.dropFirst(homePath.count)
        }
        return truncatePath(displayable)
    }
    
    // MARK: - Build detailed file info (like tooltip)
    static func buildFileDetails(_ file: CustomFile) -> String {
        let icon: String
        if file.isSymbolicLink && file.isDirectory {
            icon = "🔗📁"
        } else if file.isDirectory {
            icon = "📁"
        } else if file.isSymbolicLink {
            icon = "🔗"
        } else {
            icon = "📄"
        }
        
        let typeDesc: String
        if file.isSymbolicLink && file.isDirectory {
            typeDesc = "Symbolic Link → Directory"
        } else if file.isDirectory {
            typeDesc = "Directory"
        } else if file.isSymbolicLink {
            typeDesc = "Symbolic Link → \(file.fileExtension.isEmpty ? "File" : file.fileExtension.uppercased())"
        } else {
            typeDesc = file.fileExtension.isEmpty ? "File" : file.fileExtension.uppercased()
        }
        
        return """
            \(icon) \(file.nameStr)
            ─────────────────────────────────
            📍 Path: \(displayPath(file.pathStr))
            🧩 Type: \(typeDesc)
            📦 Size: \(file.fileSizeFormatted)
            📅 Modified: \(file.modifiedDateFormatted)
            """
    }
    
    // MARK: - Build destination info
    static func buildDestinationInfo(_ destinationURL: URL, fileName: String) -> String {
        let targetPath = destinationURL.appendingPathComponent(fileName).path
        return """
            📍 Destination: \(displayPath(targetPath))
            """
    }
}
