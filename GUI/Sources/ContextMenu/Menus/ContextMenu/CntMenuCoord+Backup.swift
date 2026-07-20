// CntMenuCoord+Backup.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Timestamped Temp-Backup archive workflow.

import FileModelKit
import Foundation

// MARK: - Temp-Backup
extension CntMenuCoord {
    // MARK: - Request Backup
    func requestBackup(files: [CustomFile], sourcePanel: FavPanelSide, appState: AppState) async {
        guard let archiveURL = BackupArchiveService.archiveURL(for: files) else { return }
        log.info("[Backup] preflight items=\(files.count) archive='\(archiveURL.lastPathComponent)'")
        let assessment = await BackupArchiveService.assess(files: files)
        log.info("[Backup] preflight \(assessment.summary) approximate=\(assessment.isApproximate) confirm=\(assessment.requiresConfirmation)")
        if assessment.requiresConfirmation {
            activeDialog = .backupConfirmation(files: files, assessment: assessment, archiveURL: archiveURL, sourcePanel: sourcePanel)
            return
        }
        await performBackup(files: files, archiveURL: archiveURL, sourcePanel: sourcePanel, showsProgress: false, appState: appState)
    }
    // MARK: - Perform Backup
    func performBackup(files: [CustomFile], archiveURL: URL, sourcePanel: FavPanelSide, showsProgress: Bool, appState: AppState) async {
        guard !isProcessing else {
            log.warning("[Backup] ignored because another operation is running")
            return
        }
        isProcessing = true
        defer { isProcessing = false }
        let progressPanel = ProgressPanel.shared
        let processHandle = ActiveArchiveProcess()
        if showsProgress {
            progressPanel.showPacking(
                archiveName: archiveURL.lastPathComponent,
                destinationPath: archiveURL.deletingLastPathComponent().path,
                fileCount: files.count,
                cancelHandler: { processHandle.terminate() }
            )
        }
        do {
            let result: URL
            if showsProgress {
                result = try await CompressService.shared.compress(
                    files: files.map(\.urlValue),
                    archiveName: archiveURL.lastPathComponent,
                    destination: archiveURL.deletingLastPathComponent(),
                    onStage: { stage in Task { @MainActor in progressPanel.updateStatus(stage) } },
                    onLog: { line in Task { @MainActor in progressPanel.appendLog(line) } },
                    onProgress: { fraction in Task { @MainActor in progressPanel.updateProgress(fraction) } },
                    processHandle: processHandle
                )
            } else {
                result = try await CompressService.shared.compress(
                    files: files.map(\.urlValue),
                    archiveName: archiveURL.lastPathComponent,
                    destination: archiveURL.deletingLastPathComponent(),
                    processHandle: processHandle
                )
            }
            await appState.refreshAndSelect(name: result.lastPathComponent, on: sourcePanel)
            log.info("[Backup] success archive='\(result.path)' items=\(files.count)")
            if showsProgress {
                progressPanel.finish(success: true, message: "Created \(result.lastPathComponent)")
            }
        } catch {
            log.error("[Backup] failed archive='\(archiveURL.path)' error='\(error.localizedDescription)'")
            if showsProgress {
                progressPanel.finish(success: false, message: error.localizedDescription)
            }
            activeDialog = .error(title: "Temp-Backup Failed", message: error.localizedDescription)
        }
    }
}
