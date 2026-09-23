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

private struct RemoteDeleteFailure: Error {
    let file: CustomFile
    let underlyingError: Error
}

extension CntMenuCoord {

    // MARK: - Panel Helpers

    private func oppositePanel(of panel: FavPanelSide) -> FavPanelSide {
        panel == .left ? .right : .left
    }

    private func refreshOppositePanel(of panel: FavPanelSide, appState: AppState) {
        refreshPanel(oppositePanel(of: panel), appState: appState)
    }

    // MARK: - Delete

    /// Delete files to trash.
    func performDelete(
        files: [CustomFile],
        sourcePanel explicitPanel: FavPanelSide? = nil,
        appState: AppState
    ) async {
        log.debug("\(#function) files.count=\(files.count) files=\(files.map { $0.nameStr })")

        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }
        let panel = explicitPanel ?? panelContaining(files: files, appState: appState)
        do {
            if appState.isRemotePanel(panel) {
                try await deleteRemote(files: files, panel: panel, appState: appState)
                return
            }
            let urls = files.map { $0.urlValue }
            let trashedURLs = try await fileOps.deleteFiles(urls)

            for file in files where file.isFromArchiveSearch {
                await ArchiveManager.shared.markDirtyByTempPath(file.pathStr)
                log.info("\(#function) marked archive dirty after deleting: \(file.nameStr)")
            }

            guard let firstFile = files.first else {
                log.warning("\(#function) nothing to refresh after delete: files list is empty")
                return
            }

            let panel = panelContaining(files: [firstFile], appState: appState)
            await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: panel)
            refreshOppositePanel(of: panel, appState: appState)
            let undo = FileOperationOutcomePresenter.moveUndo(from: trashedURLs, to: urls) {
                Task { @MainActor in
                    await appState.refreshFiles(for: .left, force: true)
                    await appState.refreshFiles(for: .right, force: true)
                }
            }
            FileOperationOutcomePresenter.success(.delete, itemCount: files.count, sourceURLs: urls, undo: undo)
            log.info("\(#function) SUCCESS deleted \(files.count) item(s) → cursor moved to next file on \(panel)")
        } catch {
            log.error("\(#function) FAILED: \(error.localizedDescription)")
            await appState.refreshFiles(for: .left, force: true)
            await appState.refreshFiles(for: .right, force: true)
            if let remoteFailure = error as? RemoteDeleteFailure {
                showDeleteError(
                    file: remoteFailure.file,
                    panelURL: appState.url(for: panel),
                    error: remoteFailure.underlyingError
                )
            } else if appState.isRemotePanel(panel), let file = files.first {
                showDeleteError(file: file, panelURL: appState.url(for: panel), error: error)
            } else {
                FileOperationOutcomePresenter.failure(.delete, error: error)
            }
        }
    }

    // MARK: - Remote Delete
    private func deleteRemote(
        files: [CustomFile],
        panel: FavPanelSide,
        appState: AppState
    ) async throws {
        let panelURL = appState.url(for: panel)
        let connection = try remoteConnection(for: panelURL)
        for file in files {
            do {
                try await connection.provider.deleteItem(at: file.pathStr, recursive: file.isDirectory)
            } catch {
                throw RemoteDeleteFailure(file: file, underlyingError: error)
            }
            log.info("[RemoteDelete] deleted path='\(file.pathStr)' directory=\(file.isDirectory)")
        }
        appState.clearMarksAfterOperation(on: panel)
        await appState.refreshAndSelectAfterRemoval(removedFiles: files, on: panel)
        FileOperationOutcomePresenter.success(.delete, itemCount: files.count, sourceURLs: files.map(\.urlValue))
    }

    private func panelContaining(files: [CustomFile], appState: AppState) -> FavPanelSide {
        let ids = Set(files.map(\.id))
        if appState.displayedFiles(for: .left).contains(where: { ids.contains($0.id) }) { return .left }
        if appState.displayedFiles(for: .right).contains(where: { ids.contains($0.id) }) { return .right }
        return appState.focusedPanel
    }

    private func showDeleteError(file: CustomFile, panelURL: URL, error: Error) {
        let nsError = error as NSError
        var components = URLComponents(url: panelURL, resolvingAgainstBaseURL: false)
        components?.path = file.pathStr
        let targetURL = components?.url ?? panelURL
        let message = """
        Operation: Delete \(file.isDirectory ? "directory" : "file")
        Path: \(targetURL.absoluteString)
        Reason: \(error.localizedDescription)
        OS error: \(nsError.domain) (\(nsError.code))
        """
        log.error("[RemoteDelete] path='\(file.pathStr)' error='\(error.localizedDescription)' domain='\(nsError.domain)' code=\(nsError.code)")
        InAppNoticeCenter.shared.showError(title: "Remote Delete Failed", message: message)
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

            log.info("[Rename] panel=\(panel) → selectAfterRename('\(newName)')")
            appState.selectAfterRename(oldFile: file, newName: newName, newURL: newURL, on: panel)
            if !AppState.isAppManagedNetworkMountPath(newURL) {
                refreshOppositePanel(of: panel, appState: appState)
            }
            let undo = FileOperationOutcomePresenter.moveUndo(from: [newURL], to: [oldURL]) {
                Task { @MainActor in
                    await appState.refreshFiles(for: .left, force: true)
                    await appState.refreshFiles(for: .right, force: true)
                }
            }
            FileOperationOutcomePresenter.success(.rename, resultURL: newURL, displayName: newURL.lastPathComponent, sourceURLs: [oldURL], undo: undo)
            log.info("[Rename] 🏁 END SUCCESS")
        } catch {
            log.error("[Rename] ❌ FAILED: \(error.localizedDescription)")
            FileOperationOutcomePresenter.failure(.rename, error: error)
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
