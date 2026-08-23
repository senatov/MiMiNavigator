// FindFilesViewModel+FileOperations.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Direct single and batch operations for Find Files results.

import FindFilesKit
import Foundation

// MARK: - Find Files File Operations
extension FindFilesViewModel {
    func selectAllResults() {
        selectedResultIDs = Set(results.map(\.id))
        selectedResult = results.first
    }

    func copyPaths(for selected: [FindFilesResult]) {
        guard !selected.isEmpty else { return }
        FindFilesSystemActions.copyPaths(selected)
        InAppNoticeCenter.shared.showToast("Copied \(selected.count) path\(selected.count == 1 ? "" : "s")", scope: .findFiles, systemImage: "doc.on.clipboard.fill", tint: .blue)
    }

    func openResults(_ selected: [FindFilesResult]) {
        selected.filter { !$0.isInsideArchive }.forEach(FindFilesSystemActions.open)
    }

    func copyResults(_ selected: [FindFilesResult]) {
        Task { @MainActor [weak self] in
            guard let destination = await FindFilesOperationPresenter.chooseDestination(prompt: "Copy") else { return }
            self?.performTransfer(selected, destination: destination, move: false)
        }
    }

    func moveResults(_ selected: [FindFilesResult]) {
        Task { @MainActor [weak self] in
            guard let destination = await FindFilesOperationPresenter.chooseDestination(prompt: "Move") else { return }
            self?.performTransfer(selected, destination: destination, move: true)
        }
    }

    func trashResults(_ selected: [FindFilesResult]) {
        let actionable = actionableResults(selected)
        Task { @MainActor [weak self] in
            guard !actionable.isEmpty, await FindFilesOperationPresenter.confirmTrash(actionable) else { return }
            let urls = actionable.map(\.fileURL)
            do {
                try await FindFilesOperationService.shared.execute(urls: urls, operation: .trash)
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
                let operation = move
                    ? FindFilesOperationService.Operation.move(destination: destination)
                    : FindFilesOperationService.Operation.copy(destination: destination)
                try await FindFilesOperationService.shared.execute(urls: urls, operation: operation)
                if move {
                    self?.removeMissingResults(from: actionable)
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
        FindFilesOperationSelection.actionableResults(from: selected)
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
