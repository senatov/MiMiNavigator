// FindFilesOperationPresenter.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Window-scoped asynchronous system panels for Find Files operations.

import AppKit
import FindFilesKit
import Foundation

// MARK: - Find Files Operation Presenter
@MainActor
enum FindFilesOperationPresenter {
    // MARK: - Choose Destination
    static func chooseDestination(prompt: String) async -> URL? {
        await chooseLocation(
            prompt: prompt,
            message: "\(prompt) selected search results to folder",
            initialURL: nil,
            canChooseFiles: false
        )
    }

    // MARK: - Choose Location
    static func chooseLocation(
        prompt: String,
        message: String,
        initialURL: URL?,
        canChooseFiles: Bool
    ) async -> URL? {
        guard let window = FindFilesCoordinator.shared.sheetWindow else { return nil }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = canChooseFiles
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = message
        panel.directoryURL = initialURL
        return await withCheckedContinuation { continuation in
            panel.beginSheetModal(for: window) { response in
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    // MARK: - Confirm Trash
    static func confirmTrash(_ results: [FindFilesResult]) async -> Bool {
        guard let window = FindFilesCoordinator.shared.sheetWindow else { return false }
        let paths = results.prefix(8).map { "• \($0.fileURL.path)" }.joined(separator: "\n")
        let remainder = results.count > 8 ? "\n…and \(results.count - 8) more" : ""
        let alert = NSAlert()
        alert.messageText = "Move \(results.count) item\(results.count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "Review the actual top-level paths before continuing:\n\n\(paths)\(remainder)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")
        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for: window) { response in
                continuation.resume(returning: response == .alertFirstButtonReturn)
            }
        }
    }
}
