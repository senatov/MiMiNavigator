//
//  FileContextMenuLog.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 31.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import FavoritesKit
import FileModelKit
import SwiftUI
import UniformTypeIdentifiers

enum FileContextMenuLog {
    static func logCacheInvalidation(_ ext: String) {
        log.debug("[FileContextMenu] apps cache cleared")
        log.debug("[FileContextMenu] cache ext='\(ext)'")
    }

    static func logCacheObserverMissingExtension() {
        log.warning("[FileContextMenu] cache invalidation without ext")
    }

    static func logFavoriteRemoved(path: String) {
        log.info("[Favorites] directory removed via context menu")
        log.info("[Favorites] path='\(path)'")
    }

    static func logInit(instanceID: Int, fileName: String, fileExtension: String, appsCount: Int, menuID: String) {
        log.debug("[FileContextMenu] init#\(instanceID) file='\(fileName)'")
        log.debug("[FileContextMenu] init#\(instanceID) ext='\(fileExtension)' apps=\(appsCount)")
        log.debug("[FileContextMenu] init#\(instanceID) menuID='\(menuID)'")
    }

    static func logBody(prefix: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) body \(snapshot.fileLine)")
        log.debug("\(prefix) \(snapshot.menuLine)")
    }

    static func logAction(prefix: String, action: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) action='\(action)' \(snapshot.fileLine)")
        log.debug("\(prefix) path='\(snapshot.path)'")
        log.debug("\(prefix) \(snapshot.menuLine)")
    }

    static func logFavoriteAdd(prefix: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) add favorite dir='\(snapshot.fileName)'")
        log.debug("\(prefix) add favorite path='\(snapshot.path)'")
    }

    static func logFavoriteRemove(prefix: String, snapshot: FileContextMenu.DebugSnapshot) {
        log.debug("\(prefix) remove favorite dir='\(snapshot.fileName)'")
        log.debug("\(prefix) remove favorite path='\(snapshot.path)'")
    }

    static func logMediaInfo(fileName: String, path: String) {
        log.debug("[FileContextMenu] media info file='\(fileName)'")
        log.debug("[FileContextMenu] media info path='\(path)'")
    }

    static func logOpenWithCacheHit(_ ext: String) {
        log.debug("[FileContextMenu] open-with cache hit ext='\(ext)'")
    }

    static func logOpenWithCacheMiss(_ ext: String) {
        log.debug("[FileContextMenu] open-with cache miss ext='\(ext)'")
    }
}
