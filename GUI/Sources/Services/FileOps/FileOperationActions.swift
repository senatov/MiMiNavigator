//
//  FileOperationActions.swift
//  MiMiNavigator
//
//  Handles user‑triggered file operations such as copy and open
//  between the two panels of the file manager.
//
//  Created by Iakov Senatov.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation

@MainActor
final class FileOperationActions {

    // MARK: - Properties

    private weak var appState: AppState?
    private let fileManager = FileManager.default

    // MARK: - Initialization

    init(appState: AppState) {
        self.appState = appState
        log.debug("[FileOperationActions] initialized")
    }

    // MARK: - Public API

    /// Copy selected file to the opposite panel
    func copyToOppositePanel() {
        guard let state = appState else {
            log.error("[FileOperationActions] appState is nil")
            return
        }

        log.debug("[FileOperationActions] copyToOppositePanel focus=\(state.focusedPanel)")

        let srcFile: CustomFile?
        let dstSide: PanelSide

        switch state.focusedPanel {
            case .left:
                srcFile = state.selectedLeftFile
                dstSide = .right
            case .right:
                srcFile = state.selectedRightFile
                dstSide = .left
        }

        guard let file = srcFile else {
            log.debug("[FileOperationActions] no file selected")
            return
        }

        guard let dstDirURL = state.pathURL(for: dstSide) else {
            log.error("[FileOperationActions] destination unavailable")
            return
        }

        performCopy(file: file, to: dstDirURL, state: state, dstSide: dstSide)
    }

    /// Open selected item with default app or enter directory
    func openSelectedItem() {
        guard let state = appState else { return }

        log.debug("[FileOperationActions] openSelectedItem focus=\(state.focusedPanel)")

        let panel = state.focusedPanel
        let file = panel == .left ? state.selectedLeftFile : state.selectedRightFile

        guard let file else {
            log.warning("[FileOperationActions] no file selected")
            return
        }

        state.activateItem(file, on: panel)
    }

    // MARK: - Private Helpers

    private func performCopy(
        file: CustomFile,
        to dstDirURL: URL,
        state: AppState,
        dstSide: PanelSide
    ) {
        let srcURL = file.urlValue
        let dstURL = dstDirURL.appendingPathComponent(srcURL.lastPathComponent)

        do {
            if fileManager.fileExists(atPath: dstURL.path) {
                log.warning("[FileOperationActions] skip: file exists at \(dstURL.path)")
                return
            }

            try fileManager.copyItem(at: srcURL, to: dstURL)

            log.info("[FileOperationActions] copied \(srcURL.lastPathComponent) → \(dstURL.path)")

            Task {
                if dstSide == .left {
                    await state.refreshLeftFiles()
                } else {
                    await state.refreshRightFiles()
                }
            }

        } catch {
            log.error("[FileOperationActions] copy failed: \(error.localizedDescription)")
        }
    }
}
