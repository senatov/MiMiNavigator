// FileActions.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Facade API for file operations (delegates to specialized modules)

import AppKit
import Foundation

/// Facade providing unified API for file operations
/// Delegates to: VSCodeIntegration, BasicFileOperations, FileDialogs, PathFormatting
enum FileActions {
    
    // MARK: - VS Code Operations
    
    /// Check if VS Code is installed
    static func isVSCodeInstalled() -> Bool {
        VSCodeIntegration.isInstalled()
    }
    
    /// Prompt user to install VS Code
    @MainActor
    static func promptVSCodeInstall(then action: @escaping () -> Void = {}) {
        VSCodeIntegration.promptInstall(then: action)
    }
    
    /// View file with VS Code
    static func view(_ file: CustomFile) {
        log.info("view - \(file.nameStr)")
        VSCodeIntegration.openFile(file)
    }
    
    /// Edit file with VS Code
    static func edit(_ file: CustomFile) {
        log.info("edit - \(file.nameStr)")
        VSCodeIntegration.openFile(file)
    }
    
    // MARK: - File Operations (with confirmation dialogs)
    
    /// Copy file with confirmation dialog
    @MainActor
    static func copyWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        FileDialogs.copyWithConfirmation(file, to: destinationURL, onComplete: onComplete)
    }
    
    /// Move file with confirmation dialog
    @MainActor
    static func moveWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        FileDialogs.moveWithConfirmation(file, to: destinationURL, onComplete: onComplete)
    }
    
    /// Delete file with confirmation dialog
    @MainActor
    static func deleteWithConfirmation(_ file: CustomFile, onConfirm: @escaping () -> Void) {
        FileDialogs.deleteWithConfirmation(file, onConfirm: onConfirm)
    }
    
    /// Create folder with input dialog
    @MainActor
    static func createFolderWithDialog(at parentURL: URL, onComplete: @escaping () -> Void) {
        FileDialogs.createFolderWithDialog(at: parentURL, onComplete: onComplete)
    }
    
    // MARK: - Direct File Operations (no dialogs)
    
    /// Copy file directly (no confirmation)
    static func copy(_ file: CustomFile, to destinationURL: URL) {
        _ = BasicFileOperations.copy(file, to: destinationURL)
    }
    
    /// Move file directly (no confirmation)
    static func move(_ file: CustomFile, to destinationURL: URL) {
        _ = BasicFileOperations.move(file, to: destinationURL)
    }
    
    /// Delete file directly (no confirmation)
    static func delete(_ file: CustomFile) {
        _ = BasicFileOperations.delete(file)
    }
    
    /// Create folder directly (no confirmation)
    static func createFolder(at parentURL: URL, name: String) -> Bool {
        BasicFileOperations.createFolder(at: parentURL, name: name)
    }
}

// MARK: - Backward Compatibility Alias
/// Alias for backward compatibility with existing code using FActions
typealias FActions = FileActions
