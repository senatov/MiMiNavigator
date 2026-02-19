//
// FavoriteItem.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

// MARK: - Default Favorite Item Implementation
/// A concrete implementation of FavoriteItemProtocol for use within the package
public struct FavoriteItem: FavoriteItemProtocol, Hashable {
    public let id: UUID
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let isSymbolicDirectory: Bool
    public let isSymbolicLink: Bool
    public let sizeInBytes: Int64
    public var children: [any FavoriteItemProtocol]?
    
    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool = true,
        isSymbolicDirectory: Bool = false,
        isSymbolicLink: Bool = false,
        sizeInBytes: Int64 = 0,
        children: [any FavoriteItemProtocol]? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.isSymbolicDirectory = isSymbolicDirectory
        self.isSymbolicLink = isSymbolicLink
        self.sizeInBytes = sizeInBytes
        self.children = children
    }
    
    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(path)
    }
    
    public static func == (lhs: FavoriteItem, rhs: FavoriteItem) -> Bool {
        lhs.id == rhs.id && lhs.path == rhs.path
    }
}

// MARK: - Convenience Initializers
public extension FavoriteItem {
    /// Creates a group item (like "Favorites", "iCloud Drive", etc.)
    static func group(name: String, children: [any FavoriteItemProtocol]) -> FavoriteItem {
        FavoriteItem(
            name: name,
            path: "",
            isDirectory: true,
            children: children
        )
    }
    
    /// Creates from URL
    static func fromURL(_ url: URL, children: [any FavoriteItemProtocol]? = nil) -> FavoriteItem {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        return FavoriteItem(
            name: url.lastPathComponent,
            path: url.path,
            isDirectory: isDir.boolValue,
            children: children
        )
    }
}
