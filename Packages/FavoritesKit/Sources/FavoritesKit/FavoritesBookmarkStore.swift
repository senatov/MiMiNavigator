//
// FavoritesBookmarkStore.swift
// FavoritesKit
//
// Created by Iakov Senatov on 17.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import Foundation

// MARK: - Security-Scoped Bookmarks Store
/// Actor-based store for managing security-scoped bookmarks (sandbox-friendly)
public actor FavoritesBookmarkStore: BookmarkStoreProtocol {
    public static let shared = FavoritesBookmarkStore()
    
    private let defaults = UserDefaults.standard
    private let key = "FavoritesKit.Bookmarks.v1"
    private var activeURLs: [String: URL] = [:]
    
    private init() {}
    
    // MARK: - Public API
    
    public func hasAccess(to url: URL) -> Bool {
        let dict = (defaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        return dict.keys.contains(url.standardizedFileURL.path)
    }
    
    public func addBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            saveBookmark(for: url.standardizedFileURL.path, data: data)
        } catch {
            print("FavoritesBookmarkStore: failed to create bookmark for \(url.path): \(error)")
        }
    }
    
    @discardableResult
    public func restoreAll() async -> [URL] {
        let dict = (defaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        var restored: [URL] = []
        
        for (path, data) in dict {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                
                if stale {
                    let newData = try url.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    saveBookmark(for: path, data: newData)
                }
                
                if url.startAccessingSecurityScopedResource() {
                    activeURLs[path] = url
                    restored.append(url)
                }
            } catch {
                print("FavoritesBookmarkStore: failed to resolve bookmark for \(path): \(error)")
            }
        }
        return restored
    }
    
    public func stopAll() {
        for (_, url) in activeURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeURLs.removeAll()
    }
    
    @MainActor
    @discardableResult
    public func requestAccessPersisting(for url: URL, anchorWindow: NSWindow? = nil) async -> Bool {
        let startDir: URL = {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            } else {
                return url.deletingLastPathComponent()
            }
        }()
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = startDir
        panel.message = "Grant access to \(startDir.path)"
        panel.prompt = "Allow"
        
        let pickedURL: URL
        if let win = anchorWindow {
            let result = await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
                panel.beginSheetModal(for: win) { response in
                    cont.resume(returning: response == .OK ? panel.urls.first : nil)
                }
            }
            guard let sel = result else { return false }
            pickedURL = sel
        } else {
            let response = panel.runModal()
            guard response == .OK, let sel = panel.urls.first else { return false }
            pickedURL = sel
        }
        
        return await persistAccess(for: pickedURL)
    }
    
    // MARK: - Private
    
    private func saveBookmark(for path: String, data: Data) {
        var dict = (defaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        dict[path] = data
        defaults.set(dict, forKey: key)
    }
    
    @discardableResult
    private func persistAccess(for pickedURL: URL) async -> Bool {
        do {
            let bookmark = try pickedURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            saveBookmark(for: pickedURL.path, data: bookmark)
            
            if pickedURL.startAccessingSecurityScopedResource() {
                activeURLs[pickedURL.path] = pickedURL
            }
            _ = await restoreAll()
            return true
        } catch {
            print("FavoritesBookmarkStore: failed to persist access for \(pickedURL.path): \(error)")
            return false
        }
    }
}
