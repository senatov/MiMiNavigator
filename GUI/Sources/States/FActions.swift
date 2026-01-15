//
// FActions.swift
//  MiMiNavigator
//
//  Created by Iakov Senatov on 28.05.2025.
//  Copyright © 2025 Senatov. All rights reserved.
//

import AppKit
import Foundation

enum FActions {
    
    // MARK: - Path display limit
    private static let maxPathDisplayLength = 256
    
    // MARK: - VS Code paths to check
    private static let vsCodePaths: [String] = [
        "/Applications/Visual Studio Code.app",
        "/usr/local/bin/code",
        "/opt/homebrew/bin/code",
        "~/Applications/Visual Studio Code.app"
    ]
    
    // MARK: - Truncate path macOS style (keeps start and end, adds … in middle)
    private static func truncatePath(_ path: String, maxLength: Int = maxPathDisplayLength) -> String {
        guard path.count > maxLength else { return path }
        
        let url = URL(fileURLWithPath: path)
        let components = url.pathComponents
        
        // If very few components, just truncate with ellipsis
        guard components.count > 3 else {
            let half = (maxLength - 3) / 2
            let start = path.prefix(half)
            let end = path.suffix(half)
            return "\(start)…\(end)"
        }
        
        // macOS style: /first/second/…/last-two/filename
        var result = ""
        var remaining = maxLength - 1  // Reserve space for …
        
        // Always include root and first component
        let root = components[0] == "/" ? "/" : components[0] + "/"
        let first = components.count > 1 ? components[1] : ""
        let prefix = root + first
        
        // Always include last two components
        let lastTwo = components.suffix(2).joined(separator: "/")
        
        // Check if we can fit prefix + … + lastTwo
        if prefix.count + 1 + lastTwo.count <= maxLength {
            return prefix + "/…/" + lastTwo
        }
        
        // If still too long, truncate the filename part
        let half = (maxLength - 3) / 2
        let start = path.prefix(half)
        let end = path.suffix(half)
        return "\(start)…\(end)"
    }
    
    // MARK: - Format path for display in dialogs
    private static func displayPath(_ path: String) -> String {
        // Replace home directory with ~
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        var displayable = path
        if displayable.hasPrefix(homePath) {
            displayable = "~" + displayable.dropFirst(homePath.count)
        }
        return truncatePath(displayable)
    }
    
    // MARK: - Build detailed file info (like tooltip)
    private static func buildFileDetails(_ file: CustomFile) -> String {
        let icon: String
        if file.isSymbolicLink && file.isDirectory {
            icon = "🔗📁"
        } else if file.isDirectory {
            icon = "📁"
        } else if file.isSymbolicLink {
            icon = "🔗"
        } else {
            icon = "📄"
        }
        
        let typeDesc: String
        if file.isSymbolicLink && file.isDirectory {
            typeDesc = "Symbolic Link → Directory"
        } else if file.isDirectory {
            typeDesc = "Directory"
        } else if file.isSymbolicLink {
            typeDesc = "Symbolic Link → \(file.fileExtension.isEmpty ? "File" : file.fileExtension.uppercased())"
        } else {
            typeDesc = file.fileExtension.isEmpty ? "File" : file.fileExtension.uppercased()
        }
        
        return """
            \(icon) \(file.nameStr)
            ─────────────────────────────────
            📍 Path: \(displayPath(file.pathStr))
            🧩 Type: \(typeDesc)
            📦 Size: \(file.fileSizeFormatted)
            📅 Modified: \(file.modifiedDateFormatted)
            """
    }
    
    // MARK: - Build destination info
    private static func buildDestinationInfo(_ destinationURL: URL, fileName: String) -> String {
        let targetPath = destinationURL.appendingPathComponent(fileName).path
        return """
            📍 Destination: \(displayPath(targetPath))
            """
    }
    
    // MARK: - Check if VS Code is installed
    static func isVSCodeInstalled() -> Bool {
        for path in vsCodePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Get VS Code app URL
    private static func getVSCodeURL() -> URL? {
        let appPaths = [
            "/Applications/Visual Studio Code.app",
            "~/Applications/Visual Studio Code.app"
        ]
        for path in appPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return URL(fileURLWithPath: expandedPath)
            }
        }
        return nil
    }
    
    // MARK: - Get VS Code CLI path
    private static func getVSCodeCLI() -> String? {
        let cliPaths = [
            "/usr/local/bin/code",
            "/opt/homebrew/bin/code",
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        ]
        for path in cliPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    // MARK: - View file with VS Code
    static func view(_ file: CustomFile) {
        log.info(#function + " - \(file.nameStr)")
        openWithVSCode(file)
    }

    // MARK: - Edit file with VS Code
    static func edit(_ file: CustomFile) {
        log.info(#function + " - \(file.nameStr)")
        openWithVSCode(file)
    }
    
    // MARK: - Open file with VS Code
    private static func openWithVSCode(_ file: CustomFile) {
        if let cliPath = getVSCodeCLI() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = [file.urlValue.path]
            do {
                try process.run()
                log.info("Opened with VS Code CLI: \(file.nameStr)")
                return
            } catch {
                log.warning("VS Code CLI failed: \(error.localizedDescription)")
            }
        }
        
        if let appURL = getVSCodeURL() {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.open(
                [file.urlValue],
                withApplicationAt: appURL,
                configuration: configuration
            ) { _, error in
                if let error = error {
                    log.error("Failed to open with VS Code: \(error.localizedDescription)")
                } else {
                    log.info("Opened with VS Code app: \(file.nameStr)")
                }
            }
            return
        }
        
        log.error("VS Code not found")
    }
    
    // MARK: - Prompt to install VS Code
    @MainActor
    static func promptVSCodeInstall(then action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "VS Code Not Found"
        alert.informativeText = "Visual Studio Code is required for View/Edit functions.\n\nWould you like to download it now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download VS Code")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "https://code.visualstudio.com/download") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Copy file to destination
    static func copy(_ file: CustomFile, to destinationURL: URL) {
        log.info(#function + " - \(file.nameStr) -> \(destinationURL.path)")
        let sourceURL = file.urlValue
        let targetURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            log.info("Copied to \(targetURL.path)")
        } catch {
            log.error("Copy failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Copy with confirmation dialog
    @MainActor
    static func copyWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        let targetPath = destinationURL.appendingPathComponent(file.urlValue.lastPathComponent).path
        
        let alert = NSAlert()
        alert.messageText = "Copy File?"
        alert.informativeText = """
            \(buildFileDetails(file))
            
            \(buildDestinationInfo(destinationURL, fileName: file.nameStr))
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if FileManager.default.fileExists(atPath: targetPath) {
                let overwriteAlert = NSAlert()
                overwriteAlert.messageText = "File Already Exists"
                overwriteAlert.informativeText = """
                    Target file already exists:
                    \(displayPath(targetPath))
                    
                    Do you want to replace it?
                    """
                overwriteAlert.alertStyle = .warning
                overwriteAlert.addButton(withTitle: "Replace")
                overwriteAlert.addButton(withTitle: "Cancel")
                
                if overwriteAlert.runModal() == .alertFirstButtonReturn {
                    do {
                        try FileManager.default.removeItem(atPath: targetPath)
                    } catch {
                        log.error("Failed to remove existing file: \(error.localizedDescription)")
                        showError(title: "Error", message: "Failed to remove existing file:\n\(error.localizedDescription)")
                        return
                    }
                } else {
                    return
                }
            }
            copy(file, to: destinationURL)
            onComplete()
        }
    }
    
    // MARK: - Move file to destination
    static func move(_ file: CustomFile, to destinationURL: URL) {
        log.info(#function + " - \(file.nameStr) -> \(destinationURL.path)")
        let sourceURL = file.urlValue
        let targetURL = destinationURL.appendingPathComponent(sourceURL.lastPathComponent)
        
        do {
            try FileManager.default.moveItem(at: sourceURL, to: targetURL)
            log.info("Moved to \(targetURL.path)")
        } catch {
            log.error("Move failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Move with confirmation dialog
    @MainActor
    static func moveWithConfirmation(_ file: CustomFile, to destinationURL: URL, onComplete: @escaping () -> Void) {
        let targetPath = destinationURL.appendingPathComponent(file.urlValue.lastPathComponent).path
        
        let alert = NSAlert()
        alert.messageText = "Move File?"
        alert.informativeText = """
            \(buildFileDetails(file))
            
            \(buildDestinationInfo(destinationURL, fileName: file.nameStr))
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if FileManager.default.fileExists(atPath: targetPath) {
                let overwriteAlert = NSAlert()
                overwriteAlert.messageText = "File Already Exists"
                overwriteAlert.informativeText = """
                    Target file already exists:
                    \(displayPath(targetPath))
                    
                    Do you want to replace it?
                    """
                overwriteAlert.alertStyle = .warning
                overwriteAlert.addButton(withTitle: "Replace")
                overwriteAlert.addButton(withTitle: "Cancel")
                
                if overwriteAlert.runModal() == .alertFirstButtonReturn {
                    do {
                        try FileManager.default.removeItem(atPath: targetPath)
                    } catch {
                        log.error("Failed to remove existing file: \(error.localizedDescription)")
                        showError(title: "Error", message: "Failed to remove existing file:\n\(error.localizedDescription)")
                        return
                    }
                } else {
                    return
                }
            }
            move(file, to: destinationURL)
            onComplete()
        }
    }
    
    // MARK: - Create new folder
    static func createFolder(at parentURL: URL, name: String) -> Bool {
        log.info(#function + " - \(name) in \(parentURL.path)")
        let folderURL = parentURL.appendingPathComponent(name)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
            log.info("Created folder: \(folderURL.path)")
            return true
        } catch {
            log.error("Create folder failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Create new folder with dialog
    @MainActor
    static func createFolderWithDialog(at parentURL: URL, onComplete: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Create New Folder"
        alert.informativeText = """
            Location:
            \(displayPath(parentURL.path))
            
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
            if FileManager.default.fileExists(atPath: folderURL.path) {
                showError(title: "Already Exists", message: "A folder with this name already exists:\n\(displayPath(folderURL.path))")
                return
            }
            
            if createFolder(at: parentURL, name: folderName) {
                onComplete()
            } else {
                showError(title: "Error", message: "Failed to create folder.")
            }
        }
    }

    // MARK: - Delete file (move to Trash)
    static func delete(_ file: CustomFile) {
        log.info(#function + " - \(file.nameStr)")
        do {
            try FileManager.default.trashItem(at: file.urlValue, resultingItemURL: nil)
            log.info("Moved to Trash: \(file.nameStr)")
        } catch {
            log.error("Delete failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete with confirmation dialog
    @MainActor
    static func deleteWithConfirmation(_ file: CustomFile, onConfirm: @escaping () -> Void) {
        log.info(#function + " - \(file.nameStr)")
        
        let alert = NSAlert()
        alert.messageText = "Delete?"
        alert.informativeText = """
            \(buildFileDetails(file))
            
            ⚠️ Will be moved to Trash
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            delete(file)
            onConfirm()
        }
    }
    
    // MARK: - Helper: Show error alert
    @MainActor
    private static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
