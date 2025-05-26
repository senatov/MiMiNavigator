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
public struct CustomFile: Identifiable, Equatable, Codable, Sendable, CustomStringConvertible {

    public let id: UUID
    public let nameStr: String
    public let pathStr: String
    public let urlValue: URL
    public let isDirectory: Bool
    public var children: [CustomFile]?

    // MARK: - Initializes full metadata for the file system entity
    public init(name: String? = nil, path: String, children: [CustomFile]? = nil) {
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

    // MARK: - Directory Check
    static func isThatDirectory(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    // MARK: -
    public var description: String {
        "CustomFile(name: \(nameStr), path: \(pathStr), isDirectory: \(isDirectory), children: \(children?.count ?? 0))"
    }
}
