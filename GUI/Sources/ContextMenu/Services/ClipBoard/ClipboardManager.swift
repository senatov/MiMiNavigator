// ClipboardManager.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 22.01.2026.
//  Copyright © 2026 Senatov. All rights reserved.

import AppKit
import FileModelKit
import Foundation
import SwiftUI

// MARK: - Clipboard Manager
/// Manages internal clipboard for Cut/Copy/Paste operations between panels
/// Similar to Total Commander behavior
@MainActor
@Observable
final class ClipboardManager {

    static let shared = ClipboardManager()

    // MARK: - State
    private(set) var files: [URL] = []
    private(set) var operation: ClipboardOperation?
    private(set) var sourcePanel: FavPanelSide?
    private var internalPasteboardChangeCount: Int = -1

    var hasContent: Bool { internalClipboardIsCurrent || hasExternalFileURLs }
    var isCut: Bool { operation == .cut }
    var isCopy: Bool { operation == .copy }

    private init() {}

    // MARK: - Copy files to clipboard
    func copy(files: [CustomFile], from panel: FavPanelSide) {
        self.files = files.map { $0.urlValue }
        self.operation = .copy
        self.sourcePanel = panel
        writeToPasteboard(self.files)
        internalPasteboardChangeCount = NSPasteboard.general.changeCount
        log.info("Clipboard: Copied \(files.count) item(s) from \(String(describing: panel))")
    }

    // MARK: - Cut files to clipboard
    func cut(files: [CustomFile], from panel: FavPanelSide) {
        self.files = files.map { $0.urlValue }
        self.operation = .cut
        self.sourcePanel = panel
        writeToPasteboard(self.files)
        internalPasteboardChangeCount = NSPasteboard.general.changeCount
        log.info("Clipboard: Cut \(files.count) item(s) from \(String(describing: panel))")
    }


    // MARK: - Write URLs to system pasteboard (Finder-compatible)
    /// Writes file URLs + text fallback so both Finder and text editors can paste.
    private func writeToPasteboard(_ urls: [URL]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        // writeObjects with NSURL — Finder reads this for file paste
        pb.writeObjects(urls.map { $0 as NSURL })
        // also add plain text fallback for text editors
        let text = urls.map { $0.path }.joined(separator: "\n")
        pb.addTypes([.string], owner: nil)
        pb.setString(text, forType: .string)
    }

    // MARK: - Paste files to destination via FileOpsEngine (TC/Finder-style)
    func paste(to destination: URL) async -> Result<[URL], Error> {
        guard let pasteSource = resolvePasteSource() else {
            return .failure(FileOpsError.operationFailed("Clipboard is empty"))
        }
        let sourceFiles = pasteSource.files
        let sourceOperation = pasteSource.operation
        let engine = FileOpsEngine.shared
        do {
            let progress: FileOpProgress
            switch sourceOperation {
            case .copy:
                progress = try await engine.copy(items: sourceFiles, to: destination)
            case .cut:
                progress = try await engine.move(items: sourceFiles, to: destination)
                if progress.errors.isEmpty && !progress.isCancelled {
                    for file in sourceFiles {
                        await ArchiveManager.shared.markDirtyByTempPath(file.path)
                    }
                    clear()
                }
            }
            if progress.isCancelled {
                return .failure(FileOpsError.operationCancelled)
            }
            log.info("Clipboard: Pasted via engine to \(destination.path)")
            return .success([destination])
        } catch {
            log.error("Clipboard paste failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    // MARK: - Clear clipboard
    func clear() {
        files = []
        operation = nil
        sourcePanel = nil
        internalPasteboardChangeCount = -1
        log.debug("Clipboard: Cleared")
    }

    // MARK: - Get summary for UI
    var summary: String {
        guard hasContent else { return "Clipboard empty" }
        if !internalClipboardIsCurrent {
            let count = externalFileURLs().count
            let itemWord = count == 1 ? "item" : "items"
            return "External \(count) \(itemWord)"
        }
        let opName = isCut ? "Cut" : "Copied"
        let itemWord = files.count == 1 ? "item" : "items"
        return "\(opName) \(files.count) \(itemWord)"
    }

    private var internalClipboardIsCurrent: Bool {
        !files.isEmpty && operation != nil && NSPasteboard.general.changeCount == internalPasteboardChangeCount
    }

    private var hasExternalFileURLs: Bool {
        !externalFileURLs().isEmpty
    }

    private func externalFileURLs() -> [URL] {
        PasteboardURLResolver.resolve(from: NSPasteboard.general)
            .filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
    }

    private func resolvePasteSource() -> (files: [URL], operation: ClipboardOperation)? {
        if internalClipboardIsCurrent, let operation {
            return (files, operation)
        }
        let externalFiles = externalFileURLs()
        guard !externalFiles.isEmpty else { return nil }
        log.info("Clipboard: using external pasteboard file URLs count=\(externalFiles.count)")
        return (externalFiles, .copy)
    }
}
