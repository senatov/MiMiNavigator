// CustomFile.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.10.24.
// Copyright © 2024-2026 Senatov. All rights reserved.
// Description: Core file/directory model for dual-panel file manager

import Foundation

// MARK: - Custom File Model
/// Represents a file or directory in the file system.
/// Handles symlinks, directories, and regular files with metadata.
public struct CustomFile: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: String
    public let nameStr: String
    public let pathStr: String
    public let urlValue: URL
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let isSymbolicDirectory: Bool
    public let sizeInBytes: Int64
    public let modifiedDate: Date?
    public let fileExtension: String
    public let posixPermissions: Int16
    public let ownerName: String
    public var children: [CustomFile]?

    // MARK: - Initializer
    public init(name: String? = nil, path: String, children: [CustomFile]? = nil) {
        let url = URL(fileURLWithPath: path).absoluteURL
        self.urlValue = url
        self.pathStr = path
        self.nameStr = (name?.isEmpty == false) ? name! : url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()

        let fm = FileManager.default
        var dir = false
        var symlink = false
        var symDir = false
        var size: Int64 = 0
        var mdate: Date?
        var permissions: Int16 = 0
        var owner: String = ""

        // Try to get attributes directly
        if !path.isEmpty, let attrs = try? fm.attributesOfItem(atPath: path) {
            if let type = attrs[.type] as? FileAttributeType {
                switch type {
                    case .typeDirectory:
                        dir = true
                    case .typeSymbolicLink:
                        symlink = true
                        // Resolve symlink to check if it points to directory
                        if let dst = try? fm.destinationOfSymbolicLink(atPath: path) {
                            let base = (path as NSString).deletingLastPathComponent
                            let target =
                                (dst as NSString).isAbsolutePath
                                ? dst
                                : (base as NSString).appendingPathComponent(dst)
                            var isDirFlag = ObjCBool(false)
                            if fm.fileExists(atPath: target, isDirectory: &isDirFlag), isDirFlag.boolValue {
                                dir = true
                                symDir = true
                            }
                        } else {
                            let resolved = url.resolvingSymlinksInPath()
                            if let rVals = try? resolved.resourceValues(forKeys: [.isDirectoryKey]),
                                rVals.isDirectory == true
                            {
                                dir = true
                                symDir = true
                            }
                        }
                    default:
                        break
                }
            }
            if let num = attrs[.size] as? NSNumber {
                size = num.int64Value
            }
            if let md = attrs[.modificationDate] as? Date {
                mdate = md
            }
            if let perm = attrs[.posixPermissions] as? NSNumber {
                permissions = perm.int16Value
            }
            if let ownerStr = attrs[.ownerAccountName] as? String {
                owner = ownerStr
            }
        } else {
            // Fallback to URL resource values
            let keys: Set<URLResourceKey> = [
                .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey,
            ]
            if let vals = try? url.resourceValues(forKeys: keys) {
                if vals.isDirectory == true { dir = true }
                if vals.isSymbolicLink == true {
                    symlink = true
                    let resolved = url.resolvingSymlinksInPath()
                    if let r2 = try? resolved.resourceValues(forKeys: [.isDirectoryKey]),
                        r2.isDirectory == true
                    {
                        dir = true
                        symDir = true
                    }
                }
                if let fs = vals.fileSize { size = Int64(fs) }
                mdate = vals.contentModificationDate
            }
        }

        self.isDirectory = dir
        self.isSymbolicLink = symlink
        self.isSymbolicDirectory = symDir
        self.sizeInBytes = size
        self.modifiedDate = mdate
        self.posixPermissions = permissions
        self.ownerName = owner
        self.children = dir ? (children ?? []) : nil
        self.id = url.path
    }

    // MARK: - Equatable & Hashable
    public static func == (lhs: CustomFile, rhs: CustomFile) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Remote file initializer (no filesystem access)
    /// Creates a CustomFile from remote server data without touching local FileManager.
    /// Used by RemoteConnectionManager for SFTP/FTP directory listings.
    init(remoteItem: RemoteFileItem) {
        let fakePath = remoteItem.path
        let url = URL(fileURLWithPath: fakePath)
        self.urlValue = url
        self.pathStr = fakePath
        self.nameStr = remoteItem.name
        self.fileExtension = remoteItem.isDirectory ? "" : (remoteItem.name as NSString).pathExtension.lowercased()
        self.isDirectory = remoteItem.isDirectory
        self.isSymbolicLink = false
        self.isSymbolicDirectory = false
        self.sizeInBytes = remoteItem.size
        self.modifiedDate = remoteItem.modified
        self.posixPermissions = 0
        self.ownerName = ""
        self.children = remoteItem.isDirectory ? [] : nil
        self.id = fakePath
    }

    // MARK: - Hidden file detection (Finder convention)
    /// A file is hidden if its name starts with a dot (Unix convention)
    /// or if macOS has marked it with the hidden flag.
    public var isHidden: Bool {
        nameStr.hasPrefix(".")
    }

    // MARK: - Parent directory entry detection
    /// Returns true if this is the synthetic ".." parent directory navigation entry
    public var isParentEntry: Bool {
        nameStr == ".."
    }

    // MARK: - Archive file detection
    /// Returns true if this file is a recognized archive format
    public var isArchiveFile: Bool {
        !isDirectory && ArchiveExtensions.isArchive(fileExtension)
    }
}
