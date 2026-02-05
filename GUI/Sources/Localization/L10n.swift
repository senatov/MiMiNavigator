// L10n.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 05.02.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Localization strings for MiMiNavigator

import Foundation

// MARK: - Localization namespace
enum L10n {
    
    // MARK: - Common Buttons
    enum Button {
        static let ok = String(localized: "OK", comment: "OK button")
        static let cancel = String(localized: "Cancel", comment: "Cancel button")
        static let create = String(localized: "Create", comment: "Create button")
        static let delete = String(localized: "Delete", comment: "Delete button")
        static let copy = String(localized: "Copy", comment: "Copy button")
        static let move = String(localized: "Move", comment: "Move button")
        static let rename = String(localized: "Rename", comment: "Rename button")
        static let replace = String(localized: "Replace", comment: "Replace button")
        static let select = String(localized: "Select", comment: "Select button")
    }
    
    // MARK: - Toolbar Buttons
    enum Toolbar {
        static let view = String(localized: "F3 View", comment: "View toolbar button")
        static let edit = String(localized: "F4 Edit", comment: "Edit toolbar button")
        static let copy = String(localized: "F5 Copy", comment: "Copy toolbar button")
        static let move = String(localized: "F6 Move", comment: "Move toolbar button")
        static let newFolder = String(localized: "F7 NewFolder", comment: "New folder toolbar button")
        static let delete = String(localized: "F8 Delete", comment: "Delete toolbar button")
        static let settings = String(localized: "Settings", comment: "Settings toolbar button")
        static let console = String(localized: "Console", comment: "Console toolbar button")
        static let exit = String(localized: "Exit", comment: "Exit toolbar button")
    }
    
    // MARK: - Dialog Titles
    enum Dialog {
        
        // MARK: Rename
        enum Rename {
            static let titleFolder = String(localized: "Rename folder", comment: "Rename folder dialog title")
            static let titleFile = String(localized: "Rename file", comment: "Rename file dialog title")
            static let placeholder = String(localized: "Name", comment: "Name field placeholder")
        }
        
        // MARK: Copy
        enum Copy {
            static let title = String(localized: "Copy File?", comment: "Copy confirmation dialog title")
        }
        
        // MARK: Move
        enum Move {
            static let title = String(localized: "Move File?", comment: "Move confirmation dialog title")
        }
        
        // MARK: Delete
        enum Delete {
            static let title = String(localized: "Delete?", comment: "Delete confirmation dialog title")
            static let warning = String(localized: "⚠️ Will be moved to Trash", comment: "Delete warning message")
        }
        
        // MARK: Create Folder
        enum CreateFolder {
            static let title = String(localized: "Create New Folder", comment: "Create folder dialog title")
            static let placeholder = String(localized: "Folder name", comment: "Folder name placeholder")
            static let defaultName = String(localized: "New Folder", comment: "Default new folder name")
            static let locationLabel = String(localized: "Location:", comment: "Location label")
            static let enterNameLabel = String(localized: "Enter folder name:", comment: "Enter folder name label")
        }
        
        // MARK: Pack/Archive
        enum Pack {
            static func title(_ itemsDescription: String) -> String {
                String(localized: "Create archive from \(itemsDescription)", comment: "Pack dialog title")
            }
            static let archiveNameLabel = String(localized: "Archive name:", comment: "Archive name label")
            static let saveToLabel = String(localized: "Save to:", comment: "Save to label")
            static let formatLabel = String(localized: "Format:", comment: "Format label")
            static let defaultArchiveName = String(localized: "Archive", comment: "Default archive name")
        }
        
        // MARK: Create Link
        enum CreateLink {
            static func title(_ fileName: String) -> String {
                String(localized: "Create link to \"\(fileName)\"", comment: "Create link dialog title")
            }
            static let linkNameLabel = String(localized: "Link name:", comment: "Link name label")
            static let typeLabel = String(localized: "Type:", comment: "Type label")
            static func inLocation(_ path: String) -> String {
                String(localized: "In: \(path)", comment: "Destination location")
            }
        }
        
        // MARK: File Already Exists
        enum FileExists {
            static let title = String(localized: "File Already Exists", comment: "File exists dialog title")
            static let replaceQuestion = String(localized: "Do you want to replace it?", comment: "Replace question")
            static let targetExists = String(localized: "Target file already exists:", comment: "Target exists message")
        }
    }
    
    // MARK: - Link Types
    enum LinkType {
        static let symbolic = String(localized: "Symbolic Link", comment: "Symbolic link type")
        static let alias = String(localized: "Finder Alias", comment: "Finder alias type")
        static let symbolicDescription = String(localized: "Unix symlink, works in Terminal", comment: "Symbolic link description")
        static let aliasDescription = String(localized: "Finder alias, macOS apps only", comment: "Alias description")
    }
    
    // MARK: - Error Messages
    enum Error {
        static let title = String(localized: "Error", comment: "Error title")
        static let invalidName = String(localized: "Invalid Name", comment: "Invalid name error title")
        static let alreadyExists = String(localized: "Already Exists", comment: "Already exists error title")
        static let nameEmpty = String(localized: "Name cannot be empty", comment: "Empty name error")
        static let nameInvalidChars = String(localized: "Name cannot contain / or :", comment: "Invalid characters error")
        static let nameInvalidCharsExtended = String(localized: "Folder name cannot contain : / or \\ characters.", comment: "Invalid characters extended error")
        static let invalidNameGeneric = String(localized: "Invalid name", comment: "Generic invalid name error")
        static let folderNameEmpty = String(localized: "Folder name cannot be empty.", comment: "Folder name empty error")
        static let failedToRemoveFile = String(localized: "Failed to remove existing file", comment: "Failed to remove file error")
        static let failedToCreateFolder = String(localized: "Failed to create folder.", comment: "Failed to create folder error")
        static func folderAlreadyExists(_ path: String) -> String {
            String(localized: "A folder with this name already exists:\n\(path)", comment: "Folder already exists error")
        }
    }
    
    // MARK: - Path Input
    enum PathInput {
        static let placeholder = String(localized: "Enter path", comment: "Path input placeholder")
        static let applyChangesHelp = String(localized: "Apply changes (⏎)", comment: "Apply changes tooltip")
        static let cancelHelp = String(localized: "Cancel (⎋)", comment: "Cancel tooltip")
        static let pathLabel = String(localized: "Path", comment: "Path label")
        static let nameLabel = String(localized: "Name", comment: "Name label")
    }
    
    // MARK: - Items Description
    enum Items {
        static func count(_ count: Int) -> String {
            String(localized: "\(count) items", comment: "Items count")
        }
    }
    
    // MARK: - Multi-Selection (Total Commander style)
    enum Selection {
        static let markByPattern = String(localized: "Mark by Pattern", comment: "Mark by pattern dialog title")
        static let unmarkByPattern = String(localized: "Unmark by Pattern", comment: "Unmark by pattern dialog title")
        static let patternHint = String(localized: "Use * and ? wildcards (e.g., *.txt, photo*)", comment: "Pattern hint")
        static func markedCount(_ count: Int) -> String {
            String(localized: "\(count) marked", comment: "Marked files count")
        }
        static func markedSize(_ size: String) -> String {
            String(localized: "\(size) selected", comment: "Marked files size")
        }
    }
    
    // MARK: - Batch Operations
    enum BatchOperation {
        // Operation types
        static let copying = String(localized: "Copying...", comment: "Copying operation")
        static let moving = String(localized: "Moving...", comment: "Moving operation")
        static let deleting = String(localized: "Deleting...", comment: "Deleting operation")
        static let packing = String(localized: "Packing...", comment: "Packing operation")
        
        // Past tense
        static let copied = String(localized: "copied", comment: "Copied past tense")
        static let moved = String(localized: "moved", comment: "Moved past tense")
        static let deleted = String(localized: "deleted", comment: "Deleted past tense")
        static let packed = String(localized: "packed", comment: "Packed past tense")
        
        // Progress dialog
        static let currentFile = String(localized: "Current file:", comment: "Current file label")
        static let cancelled = String(localized: "Operation cancelled", comment: "Operation cancelled")
        static let showErrors = String(localized: "Show Errors", comment: "Show errors button")
        static let operationErrors = String(localized: "Operation Errors", comment: "Operation errors title")
        
        static func timeRemaining(_ time: String) -> String {
            String(localized: "~\(time) remaining", comment: "Time remaining")
        }
        static func completedSuccess(_ count: Int, _ operation: String) -> String {
            String(localized: "\(count) files \(operation) successfully", comment: "Completed success")
        }
        static func completedWithErrors(_ success: Int, _ errors: Int) -> String {
            String(localized: "Completed: \(success) success, \(errors) errors", comment: "Completed with errors")
        }
        static func errorsCount(_ count: Int) -> String {
            String(localized: "\(count) errors occurred", comment: "Errors count")
        }
        
        // Confirmation dialogs for batch
        static func confirmCopy(_ count: Int, _ destination: String) -> String {
            String(localized: "Copy \(count) files to \(destination)?", comment: "Confirm batch copy")
        }
        static func confirmMove(_ count: Int, _ destination: String) -> String {
            String(localized: "Move \(count) files to \(destination)?", comment: "Confirm batch move")
        }
        static func confirmDelete(_ count: Int) -> String {
            String(localized: "Delete \(count) files?", comment: "Confirm batch delete")
        }
    }
}
