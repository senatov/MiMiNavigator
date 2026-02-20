// CustomFile+Formatting.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Formatting extensions for CustomFile display

import Foundation

// MARK: - CustomFile Formatting Extensions
extension CustomFile {
    
    // MARK: - Format bytes to human-readable string
    static func formatBytes(_ count: Int64) -> String {
        if count == 0 {
            return "0 KB"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        formatter.zeroPadsFractionDigits = false
        return formatter.string(fromByteCount: count)
    }

    // MARK: - Format date to localized string (DD.MM.YYYY HH:mm)
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Size column display (Finder-style)
    public var fileSizeFormatted: String {
        if isSymbolicLink {
            return "Alias"
        }
        if isDirectory {
            return "—"
        }
        return CustomFile.formatBytes(sizeInBytes)
    }
    
    // MARK: - Type column display (Finder-style)
    public var fileTypeDisplay: String {
        if isSymbolicLink {
            return "Alias"
        }
        if isDirectory {
            return "Folder"
        }
        if fileExtension.isEmpty {
            return "Document"
        }
        return fileExtension.uppercased()
    }
    
    // MARK: - Modified date formatted
    public var modifiedDateFormatted: String {
        guard let date = modifiedDate else {
            return "—"
        }
        return CustomFile.formatDate(date)
    }
    
    // MARK: - Legacy property for backward compatibility
    public var fileObjTypEnum: String {
        return fileSizeFormatted
    }
    
    // MARK: - Permission string (Unix-style: rwxr-xr-x)
    public var permissionsFormatted: String {
        let perms = posixPermissions
        var result = ""
        
        // Owner permissions
        result += (perms & 0o400) != 0 ? "r" : "-"
        result += (perms & 0o200) != 0 ? "w" : "-"
        result += (perms & 0o100) != 0 ? "x" : "-"
        
        // Group permissions
        result += (perms & 0o040) != 0 ? "r" : "-"
        result += (perms & 0o020) != 0 ? "w" : "-"
        result += (perms & 0o010) != 0 ? "x" : "-"
        
        // Others permissions
        result += (perms & 0o004) != 0 ? "r" : "-"
        result += (perms & 0o002) != 0 ? "w" : "-"
        result += (perms & 0o001) != 0 ? "x" : "-"
        
        return result
    }
    
    // MARK: - Owner display
    public var ownerFormatted: String {
        ownerName.isEmpty ? "—" : ownerName
    }

    // MARK: - Kind column (Finder-style verbose type label)
    public var kindFormatted: String {
        if isSymbolicLink { return "Alias" }
        if isDirectory    { return "Folder" }
        if fileExtension.isEmpty { return "Document" }
        switch fileExtension {
        case "zip", "gz", "tar", "bz2", "xz", "7z", "rar": return "\(fileExtension.uppercased()) Archive"
        case "png", "jpg", "jpeg", "heic", "gif", "webp", "tiff", "bmp": return "\(fileExtension.uppercased()) Image"
        case "mp4", "mov", "avi", "mkv", "m4v": return "\(fileExtension.uppercased()) Video"
        case "mp3", "aac", "flac", "m4a", "wav": return "\(fileExtension.uppercased()) Audio"
        case "pdf": return "PDF Document"
        case "swift": return "Swift Source"
        case "py": return "Python Script"
        case "sh", "zsh", "bash": return "Shell Script"
        case "json": return "JSON File"
        case "xml": return "XML File"
        case "md": return "Markdown"
        case "txt": return "Plain Text"
        default: return "\(fileExtension.uppercased()) File"
        }
    }

    // MARK: - Child count (number of items in a directory)
    /// Always reads from disk — children array is pre-populated as [] and unreliable.
    public var childCountFormatted: String {
        guard isDirectory else { return "—" }
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: pathStr) {
            return "\(entries.count)"
        }
        return "—"
    }

    /// Numeric child count for sorting (returns -1 for non-directories)
    public var childCountValue: Int {
        guard isDirectory else { return -1 }
        return (try? FileManager.default.contentsOfDirectory(atPath: pathStr).count) ?? 0
    }
}
