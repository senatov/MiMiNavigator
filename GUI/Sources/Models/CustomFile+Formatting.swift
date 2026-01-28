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

    // MARK: - Size column display (shows size for files, type for dirs/links)
    public var fileSizeFormatted: String {
        if isSymbolicLink && isDirectory {
            return "⤳ Folder"
        }
        if isDirectory {
            return "Folder"
        }
        if isSymbolicLink {
            return "⤳ File"
        }
        return CustomFile.formatBytes(sizeInBytes)
    }
    
    // MARK: - Type column display (file extension or directory type)
    public var fileTypeDisplay: String {
        if isSymbolicLink && isDirectory {
            return "Link → Dir"
        }
        if isDirectory {
            return "Directory"
        }
        if isSymbolicLink {
            return "Link → \(fileExtension.isEmpty ? "File" : fileExtension.uppercased())"
        }
        if fileExtension.isEmpty {
            return "—"
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
}
