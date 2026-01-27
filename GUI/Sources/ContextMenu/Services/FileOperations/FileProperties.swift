// FileProperties.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: File/folder properties data model

import Foundation

// MARK: - File Properties
/// Detailed properties of a file or directory
struct FileProperties {
    let url: URL
    let size: Int64
    let itemCount: Int
    let created: Date?
    let modified: Date?
    let isDirectory: Bool
    let isSymlink: Bool
    let permissions: Int?
    let isReadable: Bool
    let isWritable: Bool
    let isExecutable: Bool
    
    // MARK: - Computed Properties
    
    var name: String { url.lastPathComponent }
    var path: String { url.path }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var permissionsString: String {
        guard let perms = permissions else { return "---" }
        return String(format: "%o", perms)
    }
    
    var formattedCreated: String {
        guard let date = created else { return "—" }
        return Self.dateFormatter.string(from: date)
    }
    
    var formattedModified: String {
        guard let date = modified else { return "—" }
        return Self.dateFormatter.string(from: date)
    }
    
    // MARK: - Date Formatter
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
