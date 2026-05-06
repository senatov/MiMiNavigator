// ArchiveToolInstallAlert.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Install prompt for optional archive tools.

import AppKit
import Foundation

// MARK: - Archive Tool Install Alert
@MainActor
enum ArchiveToolInstallAlert {

    // MARK: - Prompt 7-Zip Install
    static func promptSevenZipInstall(reason: String) {
        let command = ExternalToolCatalog.sevenZip.installHint
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "7-Zip Required"
        alert.informativeText = """
            This archive needs 7-Zip to open.

            \(reason)

            Install via Homebrew:
            \(command)
            """
        if ExternalToolCatalog.brew.isInstalled {
            alert.addButton(withTitle: "Install Now")
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "Cancel")
        }
        handleResponse(alert.runModal(), command: command)
    }

    // MARK: - Handle Response
    private static func handleResponse(_ response: NSApplication.ModalResponse, command: String) {
        if ExternalToolCatalog.brew.isInstalled {
            switch response {
            case .alertFirstButtonReturn:
                launchBrewInstall()
            case .alertSecondButtonReturn:
                copyCommand(command)
            default:
                break
            }
            return
        }
        if response == .alertFirstButtonReturn {
            copyCommand(command)
        }
    }

    // MARK: - Launch Brew Install
    private static func launchBrewInstall() {
        guard let brewPath = ExternalToolCatalog.brew.resolvedPath,
              let formula = ExternalToolCatalog.sevenZip.brewFormula
        else {
            copyCommand(ExternalToolCatalog.sevenZip.installHint)
            return
        }
        log.info("[ArchiveToolInstall] launching \(brewPath) install \(formula)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", formula]
        process.environment = ProcessInfo.processInfo.environment
        process.terminationHandler = { proc in
            Task { @MainActor in
                showInstallResult(success: proc.terminationStatus == 0)
            }
        }
        do {
            try process.run()
        } catch {
            log.error("[ArchiveToolInstall] brew launch failed: \(error.localizedDescription)")
            showInstallResult(success: false)
        }
    }

    // MARK: - Copy Command
    private static func copyCommand(_ command: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        log.info("[ArchiveToolInstall] copied '\(command)' to clipboard")
    }

    // MARK: - Show Install Result
    private static func showInstallResult(success: Bool) {
        let alert = NSAlert()
        alert.alertStyle = success ? .informational : .warning
        alert.messageText = success ? "7-Zip Installed" : "7-Zip Installation Failed"
        alert.informativeText = success
            ? "7-Zip is ready. Try opening the archive again."
            : "Could not install 7-Zip automatically. Run in Terminal:\n\(ExternalToolCatalog.sevenZip.installHint)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
