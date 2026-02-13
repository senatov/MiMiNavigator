// FileDialogs.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Confirmation dialogs for file operations

import AppKit
import Foundation

enum FileDialogs {

    // MARK: - Copy with confirmation dialog
    @MainActor
    static func copyWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        log.debug(#function)
        let targetPath = destinationURL.appendingPathComponent(file.urlValue.lastPathComponent).path
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.Copy.title
        alert.informativeText = """
            \(PathFormatting.buildFileDetails(file))

            \(PathFormatting.buildDestinationInfo(destinationURL, fileName: file.nameStr))
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Button.copy)
        alert.addButton(withTitle: L10n.Button.cancel)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if BasicFileOperations.fileExists(atPath: targetPath) {
                guard confirmOverwrite(targetPath: targetPath) else { return }
                guard BasicFileOperations.removeItem(atPath: targetPath) else {
                    showError(title: L10n.Error.title, message: L10n.Error.failedToRemoveFile)
                    return
                }
            }
            BasicFileOperations.copy(file, to: destinationURL)
            onComplete()
        }
    }

    // MARK: - Move with confirmation dialog
    @MainActor
    static func moveWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        log.debug(#function)
        let targetPath = destinationURL.appendingPathComponent(file.urlValue.lastPathComponent).path
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.Move.title
        alert.informativeText = """
            \(PathFormatting.buildFileDetails(file))

            \(PathFormatting.buildDestinationInfo(destinationURL, fileName: file.nameStr))
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Button.move)
        alert.addButton(withTitle: L10n.Button.cancel)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if BasicFileOperations.fileExists(atPath: targetPath) {
                guard confirmOverwrite(targetPath: targetPath) else { return }
                guard BasicFileOperations.removeItem(atPath: targetPath) else {
                    showError(title: L10n.Error.title, message: L10n.Error.failedToRemoveFile)
                    return
                }
            }
            BasicFileOperations.move(file, to: destinationURL)
            onComplete()
        }
    }

    // MARK: - Delete with confirmation dialog
    @MainActor
    static func deleteWithConfirmation(_ file: CustomFile, onConfirm: @escaping () -> Void) {
        log.info("deleteWithConfirmation - \(file.nameStr)")
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.Delete.title
        alert.informativeText = """
            \(PathFormatting.buildFileDetails(file))

            \(L10n.Dialog.Delete.warning)
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Button.delete)
        alert.addButton(withTitle: L10n.Button.cancel)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            BasicFileOperations.delete(file)
            onConfirm()
        }
    }

    // MARK: - Create new folder with dialog
    @MainActor
    static func createFolderWithDialog(at parentURL: URL, onComplete: @escaping () -> Void) {
        log.debug(#function)
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.CreateFolder.title
        alert.informativeText = """
            \(L10n.Dialog.CreateFolder.locationLabel)
            \(PathFormatting.displayPath(parentURL.path))

            \(L10n.Dialog.CreateFolder.enterNameLabel)
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.Button.create)
        alert.addButton(withTitle: L10n.Button.cancel)

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        textField.stringValue = L10n.Dialog.CreateFolder.defaultName
        textField.placeholderString = L10n.Dialog.CreateFolder.placeholder
        textField.allowsEditingTextAttributes = false
        textField.cell?.allowsUndo = true
        textField.contentType = nil
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let folderName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !folderName.isEmpty else {
                showError(title: L10n.Error.invalidName, message: L10n.Error.folderNameEmpty)
                return
            }

            let invalidChars = CharacterSet(charactersIn: ":/\\")
            if folderName.rangeOfCharacter(from: invalidChars) != nil {
                showError(title: L10n.Error.invalidName, message: L10n.Error.nameInvalidCharsExtended)
                return
            }

            let folderURL = parentURL.appendingPathComponent(folderName)
            if BasicFileOperations.fileExists(atPath: folderURL.path) {
                showError(
                    title: L10n.Error.alreadyExists,
                    message: L10n.Error.folderAlreadyExists(PathFormatting.displayPath(folderURL.path)))
                return
            }

            if BasicFileOperations.createFolder(at: parentURL, name: folderName) {
                onComplete()
            } else {
                showError(title: L10n.Error.title, message: L10n.Error.failedToCreateFolder)
            }
        }
    }

    // MARK: - Confirm overwrite dialog
    @MainActor
    private static func confirmOverwrite(targetPath: String) -> Bool {
        log.debug(#function)
        let alert = NSAlert()
        alert.messageText = L10n.Dialog.FileExists.title
        alert.informativeText = """
            \(L10n.Dialog.FileExists.targetExists)
            \(PathFormatting.displayPath(targetPath))

            \(L10n.Dialog.FileExists.replaceQuestion)
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.Button.replace)
        alert.addButton(withTitle: L10n.Button.cancel)

        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: - Show error alert
    @MainActor
    static func showError(title: String, message: String) {
        log.debug(#function)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.Button.ok)
        alert.runModal()
    }
}
