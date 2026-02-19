//
// FavoritesProtocols.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Panel Side Protocol
/// Represents which panel (left or right) is active
public enum FavPanelSide: String, Sendable, Hashable {
    case left
    case right
}

// MARK: - Favorite Item Protocol
/// Protocol for favorite items that can be displayed in the tree
public protocol FavoriteItemProtocol: Identifiable, Sendable {
    var id: UUID { get }
    var name: String { get }
    var path: String { get }
    var isDirectory: Bool { get }
    var isSymbolicDirectory: Bool { get }
    var isSymbolicLink: Bool { get }
    var sizeInBytes: Int64 { get }
    var children: [any FavoriteItemProtocol]? { get set }
}

// MARK: - Favorites Navigation Delegate
/// Delegate protocol for handling navigation actions from the Favorites panel
@MainActor
public protocol FavoritesNavigationDelegate: AnyObject {
    /// Called when user selects a favorite to navigate to
    func navigateToPath(_ path: String, panel: FavPanelSide) async
    
    /// Called when user requests to go back in history
    func navigateBack(panel: FavPanelSide)
    
    /// Called when user requests to go forward in history
    func navigateForward(panel: FavPanelSide)
    
    /// Called when user requests to go up to parent directory
    func navigateUp(panel: FavPanelSide)
    
    /// Returns true if back navigation is available
    func canGoBack(panel: FavPanelSide) -> Bool
    
    /// Returns true if forward navigation is available
    func canGoForward(panel: FavPanelSide) -> Bool
    
    /// Returns current path for the panel
    func currentPath(for panel: FavPanelSide) -> String
    
    /// Sets the focused panel
    func setFocusedPanel(_ panel: FavPanelSide)
    
    /// Returns the currently focused panel
    var focusedPanel: FavPanelSide { get }
}

// MARK: - Favorites Data Source
/// Protocol for providing favorite items data
@MainActor
public protocol FavoritesDataSource: AnyObject {
    /// Scans and returns favorite directories
    func scanFavorites() -> [any FavoriteItemProtocol]
    
    /// Scans favorites and network volumes asynchronously
    func scanFavoritesAndVolumes() async -> [any FavoriteItemProtocol]
}

// MARK: - Bookmark Store Protocol
/// Protocol for security-scoped bookmark management
public protocol BookmarkStoreProtocol: Actor {
    /// Returns true if bookmark exists for URL
    func hasAccess(to url: URL) -> Bool
    
    /// Creates and saves a security-scoped bookmark
    func addBookmark(for url: URL)
    
    /// Restores all stored bookmarks
    func restoreAll() async -> [URL]
    
    /// Stops all active security-scoped resources
    func stopAll()
    
    /// Requests user access to a path via NSOpenPanel
    @MainActor
    func requestAccessPersisting(for url: URL, anchorWindow: NSWindow?) async -> Bool
}
