// DragNSView+RemoteExport.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Stages remote drag entries and reuses them after a cancelled drop.

import AppKit
import FileModelKit

// MARK: - Remote Drag Export
extension DragNSView {
    // MARK: - Handle Remote Drag
    func handleRemoteDrag(_ event: NSEvent) -> Bool {
        let key = cachedSelection.map { $0.urlValue.absoluteString }
        if let stagedRemoteDrag, stagedRemoteDrag.key == key,
           stagedRemoteDrag.expires > Date(),
           stagedRemoteDrag.urls.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) {
            beginDrag(with: cachedSelection, urls: stagedRemoteDrag.urls, event: event)
            return true
        }
        latestRemoteDragEvent = event
        if pendingRemoteDragKey != key || pendingRemoteDrag == nil {
            pendingRemoteDrag?.cancel()
            pendingRemoteDragKey = key
            prepareRemoteDrag(key: key)
        }
        return true
    }

    // MARK: - Prepare Remote Drag
    private func prepareRemoteDrag(key: [String]) {
        guard let provider = RemoteConnectionManager.shared.activeConnection?.provider else {
            pendingRemoteDragKey = nil
            log.error("[DragExport] no active provider for remote drag")
            return
        }
        let entries = cachedSelection.map { RemoteDragEntry(path: $0.urlValue.path, name: $0.nameStr, isDirectory: $0.isDirectory || $0.isSymbolicDirectory) }
        log.info("[DragExport] preparing \(entries.count) remote file(s) for drag")
        pendingRemoteDrag = Task { [weak self] in
            do {
                let urls = try await ExternalDragStaging.stage(entries, provider: provider)
                guard let self, !Task.isCancelled, self.pendingRemoteDragKey == key else {
                    ExternalDragStaging.discard(urls)
                    return
                }
                self.pendingRemoteDrag = nil
                self.pendingRemoteDragKey = nil
                self.stagedRemoteDrag = (key, urls, Date().addingTimeInterval(120))
                guard let event = self.latestRemoteDragEvent,
                      self.dragState.startPoint != nil,
                      self.cachedSelection.map({ $0.urlValue.absoluteString }) == key,
                      NSEvent.pressedMouseButtons & 1 != 0 else { return }
                self.beginDrag(with: self.cachedSelection, urls: urls, event: event)
            } catch {
                if let self, self.pendingRemoteDragKey == key {
                    self.pendingRemoteDrag = nil
                    self.pendingRemoteDragKey = nil
                }
                if !(error is CancellationError) { log.error("[DragExport] remote drag preparation failed: \(error.localizedDescription)") }
            }
        }
    }
}
