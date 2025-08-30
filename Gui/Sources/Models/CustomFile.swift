    //
    //  CustomFile.swift
    //  MiMiNavigator
    //
    //  Created by Iakov Senatov on 27.10.24.
    //  Copyright © 2024 Senatov. All rights reserved.
    //

import Foundation

public struct CustomFile: Identifiable, Equatable, Hashable, Codable, Sendable {
        // MARK: - Identity
    public let id: String
    
        // MARK: - Basic fields
    public let nameStr: String
    public let pathStr: String
    public let urlValue: URL
    
        // MARK: - FS flags
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let isSymbolicDirectory: Bool
    
        // MARK: - Metadata
    public let sizeInBytes: Int64
    public let modifiedDate: Date?
    
        // MARK: - Children (only for directories)
    public var children: [CustomFile]?
    
        // MARK: - Init
    public init(name: String? = nil, path: String, children: [CustomFile]? = nil) {
            // NOTE: Keep logs succinct to avoid noise
        log.debug("CustomFile.init(\(path))")
        let url = URL(fileURLWithPath: path).absoluteURL
        self.urlValue = url
        self.id = url.path()
        self.pathStr = path
            // Resolve FS flags once, with strict symlink handling
        let fm = FileManager.default
        var dir: Bool = false
        var symlink: Bool = false
        var symDir: Bool = false
        
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let type = attrs[.type] as? FileAttributeType {
            switch type {
            case .typeDirectory:
                    // Real on-disk directory
                dir = true
            case .typeSymbolicLink:
                    // This item is a symlink; resolve its target to decide folder-likeness
                symlink = true
                let resolved = url.resolvingSymlinksInPath()
                if let isDir = try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir == true {
                    dir = true        // Treat as directory for UI/metadata grouping
                    symDir = true     // Specifically: symlink that points to directory
                }
            default:
                    // Regular file, device, socket, etc.
                break
            }
        } else {
                // Fallback via URL resource values if attributes are unavailable
            if let isDir = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir == true {
                dir = true
            }
            if let isSym = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink, isSym == true {
                symlink = true
                let resolved = url.resolvingSymlinksInPath()
                if let isDir = try? resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir == true {
                    dir = true
                    symDir = true
                }
            }
        }
        
        self.isDirectory = dir
        self.isSymbolicLink = symlink
        self.isSymbolicDirectory = symDir
        self.nameStr = (name?.isEmpty == false) ? name! : url.lastPathComponent
            // Metadata (best-effort, safe defaults)
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        if let fileSize = values?.fileSize {
            self.sizeInBytes = Int64(fileSize)
        } else {
            self.sizeInBytes = 0
        }
        self.modifiedDate = values?.contentModificationDate
            // Children are only meaningful for directories (including symlink-to-dir)
        self.children = dir ? (children ?? []) : nil
    }
    
        // MARK: - Derived presentation helpers
    public var fileObjTypEnum: String {
        if isSymbolicLink && isDirectory {
            return "LINK → DIR."
        }
        if isDirectory {
            return "DIR."
        }
        if isSymbolicLink {
            return "LINK → FILE"
        }
        return ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
    
        /// Folders for UI purposes: real dirs or symlink-to-dir
    public var isFolderLike: Bool { isDirectory || isSymbolicDirectory }
    
        // MARK: - FS attribute helpers (kept inside the type)
    public static func isDirectory(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    public static func isSymbolicLink(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }
    
        // MARK: - Equatable / Hashable
        // Identity by canonical path is usually sufficient for file objects.
    public static func == (lhs: CustomFile, rhs: CustomFile) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
        // MARK: - Reusable formatters
    private static let modifiedDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
    
        // MARK: - Derived presentation
    public var modifiedDateFormatted: String {
        guard let d = modifiedDate else {
            return "—"
        }
        return CustomFile.modifiedDateFormatter.string(from: d)
    }
}
