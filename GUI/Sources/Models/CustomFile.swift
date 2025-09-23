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
        #if DEBUG
            log.info("CustomFile.init(\(path))")
        #endif

        let url = URL(fileURLWithPath: path).absoluteURL
        self.urlValue = url
        self.pathStr = path
        self.nameStr = (name?.isEmpty == false) ? name! : url.lastPathComponent

        let fm = FileManager.default

        var dir = false
        var symlink = false
        var symDir = false
        var size: Int64 = 0
        var mdate: Date? = nil

        // Fast path: single call to attributesOfItem, no bullshit
        if !path.isEmpty, let attrs = try? fm.attributesOfItem(atPath: path) {
            if let type = attrs[.type] as? FileAttributeType {
                switch type {
                case .typeDirectory:
                    dir = true
                case .typeSymbolicLink:
                    symlink = true
                    // Follow the symlink, check if it's a damn dir
                    if let dst = try? fm.destinationOfSymbolicLink(atPath: path) {
                        // Destination might be relative, normalize against the parent folder
                        let base = (path as NSString).deletingLastPathComponent
                        let target =
                            (dst as NSString).isAbsolutePath ? dst : (base as NSString).appendingPathComponent(dst)
                        var isDirFlag = ObjCBool(false)
                        if fm.fileExists(atPath: target, isDirectory: &isDirFlag), isDirFlag.boolValue {
                            dir = true
                            symDir = true
                        }
                    } else {
                        // Fallback: resolve with URL voodoo if destination fails
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
            // Grab size and mtime from attrs
            if let num = attrs[.size] as? NSNumber {
                size = num.int64Value
            }
            if let md = attrs[.modificationDate] as? Date {
                mdate = md
            }

        } else {
            // Plan B: one-shot fetch of all keys via URL.resourceValues
            let keys: Set<URLResourceKey> = [
                .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey,
            ]
            if let vals = try? url.resourceValues(forKeys: keys) {
                if vals.isDirectory == true { dir = true }
                if vals.isSymbolicLink == true {
                    symlink = true
                    let resolved = url.resolvingSymlinksInPath()
                    if let r2 = try? resolved.resourceValues(forKeys: [.isDirectoryKey]), r2.isDirectory == true {
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
        // Only dirs (incl. symlinked ones) get kids
        self.children = dir ? (children ?? []) : nil
        // ID = canonical URL path, cheap + deterministic compare
        self.id = url.path
    }

    // Thread-safe helpers: create fresh formatters per call to avoid shared mutable state
    private static func formatBytes(_ count: Int64) -> String {
        // Create a new formatter each time; Foundation formatters are not Sendable
        let f = ByteCountFormatter()
        f.allowedUnits = .useAll
        f.countStyle = .file
        return f.string(fromByteCount: count)
    }

    private static func formatDate(_ date: Date) -> String {
        // Create a new formatter per call to stay concurrency-safe
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
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
        return CustomFile.formatBytes(sizeInBytes)
    }

    // MARK: - Equatable / Hashable
    public static func == (lhs: CustomFile, rhs: CustomFile) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: - Derived presentation
    public var modifiedDateFormatted: String {
        guard let d = modifiedDate else {
            return "—"
        }
        return CustomFile.formatDate(d)
    }
}
