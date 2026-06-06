// FileOpsEngine+Helpers.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 14.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Shared helpers — progress panel, size calc, directory utils.

import Foundation

// MARK: - Panel & Progress Helpers

extension FileOpsEngine {

    func createProgress(items: [URL], type: FileOpType, destination: URL?) -> FileOpProgress {
        FileOpProgress(totalFiles: items.count, totalBytes: 0, type: type, destination: destination)
    }



    func showPanel(progress: FileOpProgress, itemCount: Int, operation: String = "items") {
        log.info("[FileOpsEngine] showing ProgressPanel for \(itemCount) \(operation)")
        progress.usesProgressPanel = true
        panel.show(
            icon: progress.operationType.systemImage,
            title: progress.operationType.title,
            status: "\(itemCount) item(s)",
            cancelHandler: { progress.cancel() }
        )
        if progress.showsProgressBar {
            panel.updateProgress(nil)
        } else {
            panel.hideProgress()
        }
    }



    func isDirectory(url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }



    func fileSize(url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }



    func calculateTotalSize(items: [URL]) -> Int64 {
        items.reduce(0) { $0 + fileSize(url: $1) }
    }



    func executeOpaqueDirectory(
        source: URL,
        target: URL,
        size: Int64,
        operation: FileOpType,
        progress: FileOpProgress
    ) async -> Bool {
        let result = await Task.detached(priority: .userInitiated) {
            Self.performIO(from: source, to: target, operation: operation)
        }.value
        if result.succeeded {
            progress.fileCompleted(name: source.lastPathComponent, success: true)
            progress.add(bytes: max(size, result.bytes))
            return true
        }
        if let diagnostic = result.diagnostic {
            recordFailure(diagnostic, progress: progress)
        }
        return false
    }
}


// MARK: - Cleanup & Error Reporting

extension FileOpsEngine {

    func recordFailure(_ diagnostic: FileOperationDiagnosticInfo, progress: FileOpProgress) {
        let fileName = URL(fileURLWithPath: diagnostic.path).lastPathComponent
        progress.fileCompleted(name: fileName, success: false, error: diagnostic.progressMessage)
        log.error("[FileOpsEngine] \(diagnostic.details.replacingOccurrences(of: "\n", with: " | "))")
    }



    func cleanupEmptyDirs(plan: FileOpPlan) {
        plan.flatList.filter(\.isDirectory)
            .sorted { $0.relativePath.components(separatedBy: "/").count > $1.relativePath.components(separatedBy: "/").count }
            .forEach { entry in
                let contents = (try? fm.contentsOfDirectory(atPath: entry.url.path)) ?? []
                if contents.isEmpty { try? fm.removeItem(at: entry.url) }
            }
    }
}
