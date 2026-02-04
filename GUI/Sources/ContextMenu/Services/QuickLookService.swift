// QuickLookService.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Refactored: 04.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for native macOS Quick Look preview (Space bar in Finder)

import AppKit
@preconcurrency
import Quartz

// MARK: - Quick Look Item
/// Wrapper for URL that conforms to QLPreviewItem
final class QuickLookItem: NSObject, QLPreviewItem {
    let url: URL
    
    init(url: URL) {
        self.url = url
        super.init()
    }
    
    var previewItemURL: URL! {
        return url
    }
    
    var previewItemTitle: String! {
        return url.lastPathComponent
    }
}

// MARK: - Quick Look Service
/// Manages native macOS Quick Look preview panel
@MainActor
final class QuickLookService: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    
    static let shared = QuickLookService()
    
    private var previewItems: [QLPreviewItem] = []
    
    private override init() {
        super.init()
        log.debug("\(#function) QuickLookService initialized")
    }
    
    // MARK: - Public API
    
    /// Shows Quick Look preview for a single file
    func preview(file: URL) {
        log.debug("\(#function) file='\(file.lastPathComponent)' path='\(file.path)'")
        preview(files: [file])
    }
    
    /// Shows Quick Look preview for multiple files
    func preview(files: [URL]) {
        guard !files.isEmpty else {
            log.warning("\(#function) called with empty array")
            return
        }
        
        log.info("\(#function) previewing \(files.count) file(s): \(files.map { $0.lastPathComponent })")
        
        previewItems = files.map { QuickLookItem(url: $0) }
        
        guard let panel = QLPreviewPanel.shared() else {
            log.error("\(#function) Cannot get QLPreviewPanel.shared()")
            return
        }
        
        panel.dataSource = self
        panel.delegate = self
        
        if panel.isVisible {
            log.debug("\(#function) panel already visible, reloading data")
            panel.reloadData()
        } else {
            log.debug("\(#function) showing panel")
            panel.makeKeyAndOrderFront(nil)
        }
        
        panel.reloadData()
        log.info("\(#function) Quick Look panel shown for \(files.count) item(s)")
    }
    
    /// Toggle Quick Look panel visibility
    func toggle(for file: URL) {
        log.debug("\(#function) file='\(file.lastPathComponent)'")
        
        guard let panel = QLPreviewPanel.shared() else {
            log.error("\(#function) Cannot get QLPreviewPanel.shared()")
            return
        }
        
        if panel.isVisible {
            log.debug("\(#function) hiding panel")
            panel.orderOut(nil)
        } else {
            preview(file: file)
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return MainActor.assumeIsolated {
            let count = previewItems.count
            log.debug("\(#function) returning count=\(count)")
            return count
        }
    }
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        return MainActor.assumeIsolated {
            guard index < previewItems.count else {
                log.warning("\(#function) index=\(index) out of bounds (count=\(previewItems.count))")
                return nil
            }
            let item = previewItems[index]
            log.debug("\(#function) index=\(index) returning '\(item.previewItemURL?.lastPathComponent ?? "nil")'")
            return item
        }
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        return false
    }
}
