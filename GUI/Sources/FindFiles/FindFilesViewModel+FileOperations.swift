// FindFilesViewModel+FileOperations.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Direct single and batch operations for Find Files results.

import AppKit
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
        guard !actionable.isEmpty, confirmTrash(count: actionable.count) else { return }
        let urls = actionable.map(\.fileURL)
        Task { @MainActor [weak self] in
            do {
                _ = try await FileOpsEngine.shared.delete(items: urls)
                self?.removeMissingResults(from: actionable)
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
            } catch {
                self?.errorMessage = "\(move ? "Move" : "Copy") failed: \(error.localizedDescription)"
                log.error("[FindFiles] transfer failed: \(error.localizedDescription)")
            }
        }
    }

    private func actionableResults(_ selected: [FindFilesResult]) -> [FindFilesResult] {
        selected.filter {
            !$0.isInsideArchive
                && !$0.isPasswordProtected
                && FileManager.default.fileExists(atPath: $0.fileURL.path)
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

    private func confirmTrash(count: Int) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Move \(count) item\(count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "The selected search results will be removed from their original locations."
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
