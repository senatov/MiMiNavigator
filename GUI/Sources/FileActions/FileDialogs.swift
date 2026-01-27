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
        let targetPath = destinationURL.appendingPathComponent(file.urlValue.lastPathComponent).path
        
        let alert = NSAlert()
        alert.messageText = "Copy File?"
        alert.informativeText = """
            \(PathFormatting.buildFileDetails(file))
            
            \(PathFormatting.buildDestinationInfo(destinationURL, fileName: file.nameStr))
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if BasicFileOperations.fileExists(atPath: targetPath) {
                guard confirmOverwrite(targetPath: targetPath) else { return }
                guard BasicFileOperations.removeItem(atPath: targetPath) else {
                    showError(title: "Error", message: "Failed to remove existing file")
                    return
                }
            }
            _ = BasicFileOperations.copy(file, to: destinationURL)
            onComplete()
        }
    }
    
    // MARK: - Move with confirmation dialog
    @MainActor
    static func moveWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        let targetPath = destinationURL.appendingPathComponent(file.urlValue.lastPathComponent).path
        
        let alert = NSAlert()
        alert.messageText = "Move File?"
        alert.informativeText = """
            \(PathFormatting.buildFileDetails(file))
            
            \(PathFormatting.buildDestinationInfo(destinationURL, fileName: file.nameStr))
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if BasicFileOperations.fileExists(atPath: targetPath) {
                guard confirmOverwrite(targetPath: targetPath) else { return }
                guard BasicFileOperations.removeItem(atPath: targetPath) else {
                    showError(title: "Error", message: "Failed to remove existing file")
                    return
                }
            }
            _ = BasicFileOperations.move(file, to: destinationURL)
            onComplete()
        }
    }
    
    // MARK: - Delete with confirmation dialog
    @MainActor
    static func deleteWithConfirmation(_ file: CustomFile, onConfirm: @escaping () -> Void) {
        log.info("deleteWithConfirmation - \(file.nameStr)")
        
        let alert = NSAlert()
        alert.messageText = "Delete?"
        alert.informativeText = """
            \(PathFormatting.buildFileDetails(file))
            
            ⚠️ Will be moved to Trash
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            _ = BasicFileOperations.delete(file)
            onConfirm()
        }
    }
    
    // MARK: - Create new folder with dialog
    @MainActor
    static func createFolderWithDialog(at parentURL: URL, onComplete: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Create New Folder"
        alert.informativeText = """
            Location:
            \(PathFormatting.displayPath(parentURL.path))
            
            Enter folder name:
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 350, height: 24))
        textField.stringValue = "New Folder"
        textField.placeholderString = "Folder name"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let folderName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !folderName.isEmpty else {
                showError(title: "Invalid Name", message: "Folder name cannot be empty.")
                return
            }
            
            let invalidChars = CharacterSet(charactersIn: ":/\\")
            if folderName.rangeOfCharacter(from: invalidChars) != nil {
                showError(title: "Invalid Name", message: "Folder name cannot contain : / or \\ characters.")
                return
            }
            
            let folderURL = parentURL.appendingPathComponent(folderName)
            if BasicFileOperations.fileExists(atPath: folderURL.path) {
                showError(title: "Already Exists", message: "A folder with this name already exists:\n\(PathFormatting.displayPath(folderURL.path))")
                return
            }
            
            if BasicFileOperations.createFolder(at: parentURL, name: folderName) {
                onComplete()
            } else {
                showError(title: "Error", message: "Failed to create folder.")
            }
        }
    }
    
    // MARK: - Confirm overwrite dialog
    @MainActor
    private static func confirmOverwrite(targetPath: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "File Already Exists"
        alert.informativeText = """
            Target file already exists:
            \(PathFormatting.displayPath(targetPath))
            
            Do you want to replace it?
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    // MARK: - Show error alert
    @MainActor
    static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
