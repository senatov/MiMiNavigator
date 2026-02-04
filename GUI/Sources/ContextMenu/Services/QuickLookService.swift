// QuickLookService.swift
// MiMiNavigator
//
// Created by Claude AI on 04.02.2026.
// Refactored: 04.02.2026
// Copyright © 2026 Senatov. All rights reserved.
// Description: Service for native macOS Quick Look preview (Space bar in Finder)

import AppKit
import Quartz

// MARK: - Quick Look Controller
/// NSViewController subclass that acts as Quick Look data source
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    
    static let shared = QuickLookController()
    
    private var previewItems: [QLPreviewItem] = []
    
    private override init() {
        super.init()
        log.debug("\(#function) QuickLookController initialized")
    }
    
    // MARK: - Public API
    
    func preview(urls: [URL]) {
        log.debug("\(#function) urls.count=\(urls.count) files=\(urls.map { $0.lastPathComponent })")
        
        previewItems = urls.map { QuickLookItem(url: $0) }
        
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
        log.info("\(#function) Quick Look panel shown for \(urls.count) item(s)")
    }
    
    func toggle(url: URL) {
        log.debug("\(#function) file='\(url.lastPathComponent)'")
        
        guard let panel = QLPreviewPanel.shared() else {
            log.error("\(#function) Cannot get QLPreviewPanel.shared()")
            return
        }
        
        if panel.isVisible {
            log.debug("\(#function) hiding panel")
            panel.orderOut(nil)
        } else {
            preview(urls: [url])
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        let count = previewItems.count
        log.debug("\(#function) returning count=\(count)")
        return count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard index < previewItems.count else {
            log.warning("\(#function) index=\(index) out of bounds (count=\(previewItems.count))")
            return nil
        }
        let item = previewItems[index]
        log.debug("\(#function) index=\(index) returning '\(item.previewItemURL?.lastPathComponent ?? "nil")'")
        return item
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        log.debug("\(#function) event.type=\(event.type.rawValue)")
        return false
    }
}

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

// MARK: - Quick Look Service (MainActor wrapper)
@MainActor
final class QuickLookService {
    
    static let shared = QuickLookService()
    
    private init() {
        log.debug("\(#function) QuickLookService initialized")
    }
    
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
        QuickLookController.shared.preview(urls: files)
    }
    
    /// Toggle Quick Look panel visibility
    func toggle(for file: URL) {
        log.debug("\(#function) file='\(file.lastPathComponent)'")
        QuickLookController.shared.toggle(url: file)
    }
}
