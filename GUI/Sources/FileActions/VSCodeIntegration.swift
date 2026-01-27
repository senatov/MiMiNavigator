// VSCodeIntegration.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 27.01.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: VS Code detection, launching, and installation prompts

import AppKit
import Foundation

enum VSCodeIntegration {
    
    // MARK: - VS Code paths to check
    private static let vsCodePaths: [String] = [
        "/Applications/Visual Studio Code.app",
        "/usr/local/bin/code",
        "/opt/homebrew/bin/code",
        "~/Applications/Visual Studio Code.app"
    ]
    
    // MARK: - Check if VS Code is installed
    static func isInstalled() -> Bool {
        for path in vsCodePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Get VS Code app URL
    static func getAppURL() -> URL? {
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
    static func getCLIPath() -> String? {
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
    
    // MARK: - Open file with VS Code
    static func openFile(_ file: CustomFile) {
        // Try CLI first
        if let cliPath = getCLIPath() {
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
        
        // Fallback to app bundle
        if let appURL = getAppURL() {
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
    static func promptInstall(then action: @escaping () -> Void = {}) {
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
}
