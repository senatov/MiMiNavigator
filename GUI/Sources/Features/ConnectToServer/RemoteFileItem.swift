// RemoteFileItem.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Model representing a single file/directory entry on a remote server.
//   Used by RemoteFileProvider (SFTP/FTP) to return directory listings.
//   Can be converted to CustomFile for panel display via toCustomFile().

import Foundation

// MARK: - RemoteFileItem
struct RemoteFileItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date?
    let permissions: String?

    init(
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64 = 0,
        modified: Date? = nil,
        permissions: String? = nil
    ) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
        self.permissions = permissions
    }
}

// MARK: - RemoteFileItem + Display Helpers
extension RemoteFileItem {
    var fileExtension: String {
        isDirectory ? "" : (name as NSString).pathExtension
    }

    var formattedSize: String {
        guard !isDirectory else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        guard let modified else { return "--" }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: modified)
    }

    var parentPath: String {
        (path as NSString).deletingLastPathComponent
    }
}
