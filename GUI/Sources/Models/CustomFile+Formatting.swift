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
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = .useAll
        formatter.countStyle = .file
        return formatter.string(fromByteCount: count)
    }

    // MARK: - Format date to localized string
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
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
}
