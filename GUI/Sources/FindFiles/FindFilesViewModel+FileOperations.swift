// FindFilesViewModel+FileOperations.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Direct single and batch operations for Find Files results.

import AppKit
import FindFilesKit
import Foundation

// MARK: - Find Files File Operations
extension FindFilesViewModel {
    func selectAllResults() {
        selectedResultIDs = Set(results.map(\.id))
        selectedResult = results.first
    }

    func copyPaths(for selected: [FindFilesResult]) {
        let paths = selected.map(\.filePath).joined(separator: "\n")
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
        InAppNoticeCenter.shared.showToast("Copied \(selected.count) path\(selected.count == 1 ? "" : "s")", scope: .findFiles, systemImage: "doc.on.clipboard.fill", tint: .blue)
    }

    func openResults(_ selected: [FindFilesResult]) {
        for result in selected where !result.isInsideArchive {
            NSWorkspace.shared.open(result.fileURL)
        }
    }

    func copyResults(_ selected: [FindFilesResult]) {
        guard let destination = chooseDestination(prompt: "Copy") else { return }
        performTransfer(selected, destination: destination, move: false)
    }

    func moveResults(_ selected: [FindFilesResult]) {
        guard let destination = chooseDestination(prompt: "Move") else { return }
        performTransfer(selected, destination: destination, move: true)
    }

    func trashResults(_ selected: [FindFilesResult]) {
        let actionable = actionableResults(selected)
        guard !actionable.isEmpty, confirmTrash(actionable) else { return }
        let urls = actionable.map(\.fileURL)
        Task { @MainActor [weak self] in
            do {
                _ = try await FileOpsEngine.shared.delete(items: urls)
                self?.removeMissingResults(from: actionable)
                InAppNoticeCenter.shared.showToast("Moved \(actionable.count) item\(actionable.count == 1 ? "" : "s") to Trash", scope: .findFiles, systemImage: "trash.fill", tint: .green)
            } catch {
                self?.errorMessage = "Move to Trash failed: \(error.localizedDescription)"
                log.error("[FindFiles] trash failed: \(error.localizedDescription)")
            }
        }
    }

    private func performTransfer(_ selected: [FindFilesResult], destination: URL, move: Bool) {
        let actionable = actionableResults(selected)
        guard !actionable.isEmpty else { return }
        let urls = actionable.map(\.fileURL)
        Task { @MainActor [weak self] in
            do {
                if move {
                    _ = try await FileOpsEngine.shared.move(items: urls, to: destination)
                    self?.removeMissingResults(from: actionable)
                } else {
                    _ = try await FileOpsEngine.shared.copy(items: urls, to: destination)
                }
                let verb = move ? "Moved" : "Copied"
                InAppNoticeCenter.shared.showToast("\(verb) \(actionable.count) item\(actionable.count == 1 ? "" : "s")", scope: .findFiles)
            } catch {
                self?.errorMessage = "\(move ? "Move" : "Copy") failed: \(error.localizedDescription)"
                log.error("[FindFiles] transfer failed: \(error.localizedDescription)")
            }
        }
    }

    private func actionableResults(_ selected: [FindFilesResult]) -> [FindFilesResult] {
        let existing = selected.filter {
            !$0.isInsideArchive
                && !$0.isPasswordProtected
                && FileManager.default.fileExists(atPath: $0.fileURL.path)
        }
        let ordered = existing.sorted {
            $0.fileURL.standardizedFileURL.pathComponents.count
                < $1.fileURL.standardizedFileURL.pathComponents.count
        }
        var acceptedPaths: [String] = []
        return ordered.filter { result in
            let path = result.fileURL.standardizedFileURL.path
            let isNested = acceptedPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
            if !isNested { acceptedPaths.append(path) }
            return !isNested
        }
    }

    private func chooseDestination(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = "\(prompt) selected search results to folder"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func confirmTrash(_ results: [FindFilesResult]) -> Bool {
        let paths = results.prefix(8).map { "• \($0.fileURL.path)" }.joined(separator: "\n")
        let remainder = results.count > 8 ? "\n…and \(results.count - 8) more" : ""
        let alert = NSAlert()
        alert.messageText = "Move \(results.count) item\(results.count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "Review the actual top-level paths before continuing:\n\n\(paths)\(remainder)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func removeMissingResults(from operated: [FindFilesResult]) {
        let missingIDs = Set(operated.filter {
            !FileManager.default.fileExists(atPath: $0.fileURL.path)
        }.map(\.id))
        guard !missingIDs.isEmpty else { return }
        results.removeAll { missingIDs.contains($0.id) }
        selectedResultIDs.subtract(missingIDs)
        if let selectedResult, missingIDs.contains(selectedResult.id) {
            self.selectedResult = nil
        }
    }
}
