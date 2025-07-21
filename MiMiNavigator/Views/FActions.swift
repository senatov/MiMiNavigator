//
//  FActions.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Foundation

enum FActions {

    // MARK: -
    static func view(_ file: CustomFile) {
        NSWorkspace.shared.open(file.urlValue)  // Открытие в системе
    }

    // MARK: -
    static func edit(_ file: CustomFile) {
        let appURL = URL(fileURLWithPath: "/Applications/TextEdit.app")
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [file.urlValue],
            withApplicationAt: appURL,
            configuration: configuration
        ) { app, error in
            if let error = error {
                log.debug("❌ Failed to open file with TextEdit: \(error.localizedDescription)")
            }
        }
    }

    // MARK: -
    static func copy(_ file: CustomFile, to destinationURL: URL) {
        let sourceURL = file.urlValue
        let targetURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            print("✅ Copied to \(targetURL.path)")
        }
        catch {
            log.debug("❌ Copy failed: \(error.localizedDescription)")
        }
    }

    // MARK: -
    static func delete(_ file: CustomFile) {
        do {
            try FileManager.default.trashItem(at: file.urlValue, resultingItemURL: nil)
        }
        catch {
            log.debug("❌ Failed to delete file: \(error.localizedDescription)")
        }
    }

    // MARK: -
    @MainActor
    static func deleteWithConfirmation(_ file: CustomFile, onConfirm: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete \"\(file.nameStr)\"?"
        alert.informativeText = "This file will be moved to Trash."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            delete(file)
            onConfirm()
        }
    }
}
