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
    public var children: [CustomFile]?

    // MARK: - Initializes full metadata for the file system entity
    public init(name: String? = nil, path: String, children: [CustomFile]? = nil) {
        //log.info(#function)
        self.id = UUID()
        self.urlValue = URL(fileURLWithPath: path).absoluteURL
        self.pathStr = path
        self.isDirectory = CustomFile.isThatDirectory(atPath: path)
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

}


extension CustomFile {

    var modifiedDate: Date {
        (try? urlValue.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    var modifiedDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modifiedDate)
    }
    
    var sizeInBytes: Int64 {
        (try? urlValue.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}
