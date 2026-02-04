// ShareService.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for macOS Share functionality

import AppKit
import Foundation

// MARK: - Share Service
/// Handles macOS native Share sheet functionality
@MainActor
final class ShareService {
    
    static let shared = ShareService()
    
    private init() {
        log.debug("\(#function) ShareService initialized")
    }
    
    // MARK: - Show Share Picker
    
    /// Shows the native macOS Share sheet for the given files
    func showSharePicker(for fileURLs: [URL], from view: NSView, at point: NSPoint? = nil) {
        guard !fileURLs.isEmpty else {
            log.warning("\(#function) called with empty array")
            return
        }
        
        log.info("\(#function) sharing \(fileURLs.count) item(s): \(fileURLs.map { $0.lastPathComponent })")
        
        let picker = NSSharingServicePicker(items: fileURLs)
        
        let showPoint = point ?? NSPoint(x: view.bounds.midX, y: view.bounds.midY)
        let rect = NSRect(origin: showPoint, size: .zero)
        
        log.debug("\(#function) showing picker at point=\(showPoint)")
        picker.show(relativeTo: rect, of: view, preferredEdge: .minY)
    }
    
    /// Shows Share sheet from SwiftUI context (needs window)
    func showSharePicker(for fileURLs: [URL]) {
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else {
            log.warning("\(#function) no key window available, cannot show share picker")
            return
        }
        
        log.debug("\(#function) using keyWindow contentView")
        showSharePicker(for: fileURLs, from: contentView)
    }
}
