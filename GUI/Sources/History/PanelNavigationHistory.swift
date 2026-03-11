// PanelNavigationHistory.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 17.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Per-panel navigation history for Back/Forward buttons

import Foundation
import FileModelKit

// MARK: - Per-Panel Navigation History
/// Manages browser-style back/forward navigation for a single panel
@MainActor
@Observable
final class PanelNavigationHistory {
    
    private let panel: PanelSide
    private let userDefaultsKey: String
    
    /// Stack of visited paths (oldest first, newest last)
    private var history: [String] = []
    
    /// Current position in history (points to current path)
    private var currentIndex: Int = -1 {
        didSet {
            updateNavigationState()
        }
    }
    
    // MARK: - Navigation State (stored for SwiftUI reactivity)
    
    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false
    
    private func updateNavigationState() {
        canGoBack = currentIndex > 0
        canGoForward = currentIndex < history.count - 1
    }
    
    var currentPath: String? {
        guard currentIndex >= 0, currentIndex < history.count else { return nil }
        return history[currentIndex]
    }
    
    // MARK: - Init
    
    init(panel: PanelSide) {
        self.panel = panel
        self.userDefaultsKey = "PanelNavigationHistory.\(panel)"
        load()
        log.debug("\(#function) panel=\(panel) loaded \(history.count) entries, currentIndex=\(currentIndex)")
    }
    
    // MARK: - Navigation
    
    /// Navigate to a new path (called when user enters a directory)
    func navigateTo(_ path: String) {
        let normalized = normalize(path)
        guard !normalized.isEmpty else { return }
        
        log.debug("\(#function) panel=\(panel) path=\(normalized) currentIndex=\(currentIndex) historyCount=\(history.count)")
        
        // If we're not at the end, truncate forward history
        if currentIndex < history.count - 1 {
            log.debug("\(#function) truncating forward history from index \(currentIndex + 1)")
            history = Array(history.prefix(currentIndex + 1))
            updateNavigationState()
        }
        
        // Don't add duplicate of current path
        if history.last == normalized {
            log.debug("\(#function) panel=\(panel) skip duplicate: \(normalized)")
            return
        }
        
        history.append(normalized)
        currentIndex = history.count - 1
        
        // Trim old history
        let maxEntries = 100
        if history.count > maxEntries {
            let removeCount = history.count - maxEntries
            history.removeFirst(removeCount)
            currentIndex -= removeCount
        }
        
        save()
        log.info("\(#function) panel=\(panel) added: \(normalized.components(separatedBy: "/").suffix(3).joined(separator: "/")) index=\(currentIndex)/\(history.count)")
    }
    
    /// Go back in history, returns path to navigate to
    func goBack() -> String? {
        log.debug("\(#function) panel=\(panel) canGoBack=\(canGoBack) currentIndex=\(currentIndex) historyCount=\(history.count)")
        
        if !history.isEmpty {
            log.debug("\(#function) history: \(history.enumerated().map { "\($0.offset): \($0.element.components(separatedBy: "/").suffix(2).joined(separator: "/"))" })")
        }
        
        guard canGoBack else {
            log.debug("\(#function) panel=\(panel) cannot go back")
            return nil
        }
        
        currentIndex -= 1
        save()
        
        let path = history[currentIndex]
        log.info("\(#function) panel=\(panel) → \(path) index=\(currentIndex)")
        return path
    }
    
    /// Go forward in history, returns path to navigate to
    func goForward() -> String? {
        log.debug("\(#function) panel=\(panel) canGoForward=\(canGoForward) currentIndex=\(currentIndex) historyCount=\(history.count)")
        
        if !history.isEmpty {
            log.debug("\(#function) history: \(history.enumerated().map { "\($0.offset): \($0.element.components(separatedBy: "/").suffix(2).joined(separator: "/"))" })")
        }
        
        guard canGoForward else {
            log.debug("\(#function) panel=\(panel) cannot go forward")
            return nil
        }
        
        currentIndex += 1
        save()
        
        let path = history[currentIndex]
        log.info("\(#function) panel=\(panel) → \(path) index=\(currentIndex)")
        return path
    }
    
    /// Get back history for dropdown menu
    func getBackHistory(limit: Int = 10) -> [String] {
        guard currentIndex > 0 else { return [] }
        let start = max(0, currentIndex - limit)
        return Array(history[start..<currentIndex].reversed())
    }
    
    /// Get forward history for dropdown menu
    func getForwardHistory(limit: Int = 10) -> [String] {
        guard currentIndex < history.count - 1 else { return [] }
        let end = min(history.count, currentIndex + 1 + limit)
        return Array(history[(currentIndex + 1)..<end])
    }
    
    /// Jump to specific path in history (for dropdown menu)
    func jumpTo(_ path: String) -> Bool {
        let normalized = normalize(path)
        if let idx = history.firstIndex(of: normalized) {
            currentIndex = idx
            save()
            log.debug("\(#function) panel=\(panel) jumped to index=\(idx)")
            return true
        }
        return false
    }
    
    // MARK: - Persistence
    
    private func save() {
        let data: [String: Any] = [
            "history": history,
            "currentIndex": currentIndex
        ]
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.dictionary(forKey: userDefaultsKey),
              let hist = data["history"] as? [String],
              let idx = data["currentIndex"] as? Int else {
            return
        }
        
        // Validate paths exist (allow remote paths through)
        history = hist.filter { path in
            if AppState.isRemotePath(path) { return true }
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }
        
        // Adjust index if needed
        if history.isEmpty {
            currentIndex = -1
        } else if idx >= history.count {
            currentIndex = history.count - 1
        } else if idx < 0 {
            currentIndex = 0
        } else {
            currentIndex = idx
        }
        updateNavigationState()
    }
    
    // MARK: - Helpers
    
    private func normalize(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.standardizedFileURL.path
    }
    
    /// Clear history (for testing or reset)
    func clear() {
        history.removeAll()
        currentIndex = -1
        save()
    }
}
