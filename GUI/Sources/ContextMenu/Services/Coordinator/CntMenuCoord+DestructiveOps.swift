//
//  CntMenuCoord+DestructiveOps.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//
import AppKit
import FileModelKit
import Foundation

extension ContextMenuCoordinator {

    // MARK: - Panel Helpers

    private func oppositePanel(of panel: FavPanelSide) -> FavPanelSide {
        panel == .left ? .right : .left
    }

    private func refreshOppositePanel(of panel: FavPanelSide, appState: AppState) {
        refreshPanel(oppositePanel(of: panel), appState: appState)
    }

    // MARK: - Delete

    /// Delete files to trash.
    func performDelete(files: [CustomFile], appState: AppState) async {
        log.debug("\(#function) files.count=\(files.count) files=\(files.map { $0.nameStr })")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }

        do {
            let urls = files.map { $0.urlValue }
            _ = try await fileOps.deleteFiles(urls)

            for file in files where file.isFromArchiveSearch {
                await ArchiveManager.shared.markDirtyByTempPath(file.pathStr)
                log.info("\(#function) marked archive dirty after deleting: \(file.nameStr)")
            }

            guard let firstFile = files.first else {
                log.warning("\(#function) nothing to refresh after delete: files list is empty")
                return
            }

            let panel = panelForPath(firstFile.urlValue.deletingLastPathComponent().path, appState: appState)
            await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: panel)
            refreshOppositePanel(of: panel, appState: appState)
            log.info("\(#function) SUCCESS deleted \(files.count) item(s) → cursor moved to next file on \(panel)")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Rename

    func performRename(file: CustomFile, newName: String, panel: FavPanelSide, appState: AppState) async {
        log.info("[Rename] 🏁 START: '\(file.nameStr)' → '\(newName)' path='\(file.pathStr)' panel=\(panel)")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }

        do {
            let oldURL = resolveSourceURL(file.urlValue)
            let newURL = try await fileOps.renameFile(oldURL, to: newName)
            let exists = FileManager.default.fileExists(atPath: newURL.path)
            log.info("[Rename] ✅ FileManager.moveItem done: newURL='\(newURL.path)' exists=\(exists)")

            if file.isFromArchiveSearch {
                await ArchiveManager.shared.markDirtyByTempPath(file.pathStr)
                log.info("[Rename] marked archive dirty after renaming: \(file.nameStr)")
            }

            alignPanelPathAfterRename(panel: panel, renamedURL: newURL, appState: appState)

            log.info("[Rename] panel=\(panel) → refreshAndSelect('\(newName)')")
            await appState.refreshAndSelect(name: newName, on: panel)
            refreshOppositePanel(of: panel, appState: appState)
            log.info("[Rename] 🏁 END SUCCESS")
        } catch {
            log.error("[Rename] ❌ FAILED: \(error.localizedDescription)")
            activeDialog = .error(title: "Rename Failed", message: error.localizedDescription)
        }
    }

    private func alignPanelPathAfterRename(panel: FavPanelSide, renamedURL: URL, appState: AppState) {
        let currentPath = appState.url(for: panel).path
        let renamedParentPath = renamedURL.deletingLastPathComponent().path

        if PathUtils.areEqual(currentPath, renamedParentPath) {
            return
        }

        let currentURL = URL(fileURLWithPath: currentPath)
        let resolvedCurrent = resolveSourceURL(currentURL)
        let resolvedParent = resolveSourceURL(renamedURL.deletingLastPathComponent())

        if PathUtils.areEqual(resolvedCurrent.path, resolvedParent.path) {
            log.info("[Rename] aligning panel path after rename: '\(currentPath)' → '\(renamedParentPath)'")
            navigateTo(resolvedParent, panel: panel, appState: appState)
        }
    }
}
