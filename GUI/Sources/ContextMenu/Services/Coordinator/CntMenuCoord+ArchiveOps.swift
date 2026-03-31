//
//  CntMenuCoord+ArchiveOps.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 30.03.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import AppKit
import FileModelKit
import Foundation

extension ContextMenuCoordinator {

    // MARK: - Pack (Archive with options)
    /// Pack files into archive — shows ProgressPanel, supports cancel + rollback.
    func performPack(
        files: [CustomFile],
        archiveName: String,
        format: ArchiveFormat,
        destination: URL,
        deleteSource: Bool = false,
        compressionLevel: CompressionLevel = .normal,
        password: String? = nil,
        appState: AppState
    ) async {
        let fullName = "\(archiveName).\(format.fileExtension)"
        log.info(
            "[Pack] \(#function) start — '\(fullName)' files=\(files.count) dest='\(destination.path)' level=\(compressionLevel) deleteSource=\(deleteSource) encrypted=\(password != nil)"
        )
        isProcessing = true
        defer {
            isProcessing = false
            activeDialog = nil
        }
        let progressPanel = ProgressPanel.shared
        let handle = ActiveArchiveProcess()

        // show progress HUD
        await MainActor.run {
            progressPanel.showPacking(
                archiveName: fullName,
                destinationPath: destination.path,
                fileCount: files.count,
                cancelHandler: { [handle] in
                    log.info("[Pack] user cancelled — terminating process")
                    handle.terminate()
                }
            )
        }
    }
}
