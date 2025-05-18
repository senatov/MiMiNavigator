//
//  CustomFile.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 27.10.24.
//  Copyright © 2024 Senatov. All rights reserved.
//

import Foundation
import SwiftyBeaver

// MARK: - CustomFile: File & Folder Representation
/// Represents a file system entity (file or directory) with metadata
public struct CustomFile: Identifiable, Equatable, Codable, Sendable, CustomStringConvertible {

    public let id: UUID
    /// Display name of the file or folder; may be synthesized
    public let nameStr: String
    public let pathStr: String
    public let url: URL
    public let isDirectory: Bool
    public var children: [CustomFile]?

    public var description: String {
        "description"
    }

    // Convenience initializer using only path
    public init(path: String) {
        self.init(name: "", path: path, children: nil)
    }

    // MARK: - Equatable Implementation
    public static func == (lhs: CustomFile, rhs: CustomFile) -> Bool {
        lhs.pathStr == rhs.pathStr
    }

    // Initializes full metadata for the file system entity
    public init(name: String = "", path: String, children: [CustomFile]? = nil) {
        self.id = UUID()
        let url = URL(fileURLWithPath: path)
        self.url = url
        self.pathStr = path
        let isDirectory = CustomFile.isThatDirectory(atPath: path)
        self.isDirectory = isDirectory
        self.nameStr = CustomFile.resolveName(from: path, fallback: name)
        self.children = isDirectory ? children ?? [] : nil
    }

    // MARK: - Directory Check
    static func isThatDirectory(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    // MARK: - Utility: Resolve Display Name
    private static func resolveName(from path: String, fallback: String?) -> String {
        let url = URL(fileURLWithPath: path)
        return fallback?.isEmpty == false ? fallback! : url.lastPathComponent
    }
}
