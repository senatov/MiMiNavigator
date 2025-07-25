//
//  CustomFile.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftyBeaver

// MARK: - Represents a file system entity (file or directory) with metadata
public struct CustomFile: Identifiable, Equatable, Hashable, Codable, Sendable  {

    public let id: UUID
    public let nameStr: String
    public let pathStr: String
    public let urlValue: URL
    public let isDirectory: Bool
    public let isSymbolicDirectory: Bool 
    public var children: [CustomFile]?

    // MARK: - Initializes full metadata for the file system entity
    public init(name: String? = nil, path: String, children: [CustomFile]? = nil) {
        //log.info(#function)
        self.id = UUID()
        self.urlValue = URL(fileURLWithPath: path).absoluteURL
        self.pathStr = path
        self.isDirectory = CustomFile.isThatDirectory(atPath: path)
        self.isSymbolicDirectory = CustomFile.isThatSymbolic(atPath: path)
        self.nameStr = name?.isEmpty == false ? name! : urlValue.lastPathComponent
        self.children = isDirectory ? children ?? [] : nil
    }

    // MARK: - Equatable Implementation
    public static func == (lhs: CustomFile, rhs: CustomFile) -> Bool {
        lhs.pathStr == rhs.pathStr
    }

    // MARK: - Hashable Implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pathStr)
    }

    // MARK: - Directory Check
    static func isThatDirectory(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    // MARK: - Directory Check
    static func isThatSymbolic(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) ?? false
    }
}


// MARK: -
extension CustomFile {

    // MARK: -
    var modifiedDate: Date {
        (try? urlValue.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    // MARK: -
    var modifiedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: modifiedDate)
    }
    
    // MARK: -
    var sizeInBytes: Int64 {
        (try? urlValue.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
    }

    // MARK: -
    var formattedSize: String {
        if isDirectory && isSymbolicDirectory {
            return "LINK → DIR."
        } else if isDirectory {
            return "DIR."
        } else {
            return ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
        }
    }
}
