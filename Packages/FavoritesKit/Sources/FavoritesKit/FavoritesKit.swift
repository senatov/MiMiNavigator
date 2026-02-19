//
// FavoritesKit.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

/// FavoritesKit - A reusable Swift package for macOS Favorites navigation
///
/// This package provides:
/// - `FavoritesTreeView` - Main popup view for displaying favorites
/// - `FavoritesScanner` - Scanner for favorites, iCloud, OneDrive, and volumes
/// - `FavoritesBookmarkStore` - Security-scoped bookmark management
/// - `FavoriteItem` - Model for favorite items
///
/// Usage:
/// ```swift
/// import FavoritesKit
///
/// // Create scanner
/// let scanner = FavoritesScanner()
/// let items = await scanner.scanFavoritesAndVolumes()
///
/// // Display in popup
/// FavoritesTreeView(
///     items: $items,
///     isPresented: $showPopup,
///     panelSide: .left,
///     navigationDelegate: myDelegate
/// )
/// ```
public enum FavoritesKit {
    public static let version = "1.0.0"
}
