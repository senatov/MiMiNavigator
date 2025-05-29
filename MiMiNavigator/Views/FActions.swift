//
//  FActions.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Foundation
import SwiftyBeaver

enum FActions {

    // MARK: - Open file in default viewer (F3)
    static func view(_ file: CustomFile) {
        let result = NSWorkspace.shared.open(file.urlValue)
        if !result {
            log.error("Failed to open file: \(file.pathStr)")
        }
    }

    // MARK: - Open file in TextEdit (F4)
    static func edit(_ file: CustomFile) {
        let appURL = URL(fileURLWithPath: "/Applications/TextEdit.app")
        let configuration = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.open(
            [file.urlValue],
            withApplicationAt: appURL,
            configuration: configuration
        ) { app, error in
            if let error = error {
                log.error("Failed to open file with TextEdit: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Ask for delete confirmation, then delete (F8)
    @MainActor
    static func deleteWithConfirmation(_ file: CustomFile, onConfirm: @escaping () -> Void = {}) {
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

    // MARK: - Move file to Trash
    private static func delete(_ file: CustomFile) {
        do {
            try FileManager.default.trashItem(at: file.urlValue, resultingItemURL: nil)
            log.info("File moved to trash: \(file.pathStr)")
        } catch {
            log.error("Failed to delete file: \(error.localizedDescription)")
        }
    }

    // MARK: - Copy file to new location (F5 - future)
    static func copy(_ file: CustomFile, to destination: URL) {
        let destinationURL = destination.appendingPathComponent(file.nameStr)
        do {
            try FileManager.default.copyItem(at: file.urlValue, to: destinationURL)
            log.info("Copied file to: \(destinationURL.path)")
        } catch {
            log.error("Failed to copy file: \(error.localizedDescription)")
        }
    }

    // MARK: - Move file to new location (F6 - future)
    static func move(_ file: CustomFile, to destination: URL) {
        let destinationURL = destination.appendingPathComponent(file.nameStr)
        do {
            try FileManager.default.moveItem(at: file.urlValue, to: destinationURL)
            log.info("Moved file to: \(destinationURL.path)")
        } catch {
            log.error("Failed to move file: \(error.localizedDescription)")
        }
    }

    @MainActor
    static func newFolder(in destination: URL, folderName: String = "New Folder") {
        let targetURL = destination.appendingPathComponent(folderName)
        var finalURL = targetURL
        var count = 1

        while FileManager.default.fileExists(atPath: finalURL.path) {
            finalURL = destination.appendingPathComponent("\(folderName) \(count)")
            count += 1
        }

        do {
            try FileManager.default.createDirectory(at: finalURL, withIntermediateDirectories: true)
            log.info("New folder created at: \(finalURL.path)")
        } catch {
            log.error("Failed to create folder: \(error.localizedDescription)")
        }
    }

}
