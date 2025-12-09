//
// CustomFile.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation

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
    public var children: [CustomFile]?

    // MARK: -
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

        if !path.isEmpty, let attrs = try? fm.attributesOfItem(atPath: path) {
            if let type = attrs[.type] as? FileAttributeType {
                switch type {
                    case .typeDirectory:
                        dir = true
                    case .typeSymbolicLink:
                        symlink = true
                        if let dst = try? fm.destinationOfSymbolicLink(atPath: path) {
                            let base = (path as NSString).deletingLastPathComponent
                            let target =
                                (dst as NSString).isAbsolutePath ? dst : (base as NSString).appendingPathComponent(dst)
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

        } else {
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
        self.children = dir ? (children ?? []) : nil
        self.id = url.path
    }

    // MARK: -
    private static func formatBytes(_ count: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = .useAll
        f.countStyle = .file
        return f.string(fromByteCount: count)
    }

    // MARK: -
    private static func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }

    // MARK: -
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

    // MARK: -
    public static func == (lhs: CustomFile, rhs: CustomFile) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: -
    public var modifiedDateFormatted: String {
        guard let d = modifiedDate else {
            return "—"
        }
        return CustomFile.formatDate(d)
    }
}
