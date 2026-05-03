// GifskiInstallAlert.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 03.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Prompts user to install gifski via Homebrew or shows the command to run manually.

import AppKit
import Foundation


// MARK: - GifskiInstallAlert

@MainActor
enum GifskiInstallAlert {

    private static let brewCommand = "brew install gifski"

    private static let homebrewPaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew",
    ]


    /// Shows alert offering to install gifski. Returns true if user chose to install.
    @discardableResult
    static func promptInstall() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "gifski Not Installed"
        alert.informativeText = """
            gifski produces much higher quality GIFs with smaller file sizes \
            than ffmpeg alone (temporal dithering, cross-frame palettes).

            Install via Homebrew:
            \(brewCommand)

            Without gifski, GIF conversion will fall back to ffmpeg \
            (lower quality, larger files).
            """

        if homebrewIsAvailable() {
            alert.addButton(withTitle: "Install Now")
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "Use ffmpeg Instead")
        } else {
            alert.addButton(withTitle: "Copy Command")
            alert.addButton(withTitle: "Use ffmpeg Instead")
        }

        let response = alert.runModal()

        if homebrewIsAvailable() {
            switch response {
            case .alertFirstButtonReturn:
                launchBrewInstall()
                return true
            case .alertSecondButtonReturn:
                copyCommandToClipboard()
                return false
            default:
                return false
            }
        } else {
            switch response {
            case .alertFirstButtonReturn:
                copyCommandToClipboard()
                return false
            default:
                return false
            }
        }
    }


    private static func homebrewIsAvailable() -> Bool {
        homebrewPaths.contains {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }


    private static func resolvedBrewPath() -> String {
        homebrewPaths.first {
            FileManager.default.isExecutableFile(atPath: $0)
        } ?? "/opt/homebrew/bin/brew"
    }


    private static func launchBrewInstall() {
        let brewPath = resolvedBrewPath()
        log.info("[GifskiInstall] launching: \(brewPath) install gifski")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments = ["install", "gifski"]
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { proc in
            Task { @MainActor in
                if proc.terminationStatus == 0 {
                    showInstallResult(success: true)
                } else {
                    showInstallResult(success: false)
                }
            }
        }

        do {
            try process.run()
        } catch {
            log.error("[GifskiInstall] brew launch failed: \(error.localizedDescription)")
            showInstallResult(success: false)
        }
    }


    private static func copyCommandToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(brewCommand, forType: .string)
        log.info("[GifskiInstall] copied '\(brewCommand)' to clipboard")
    }


    private static func showInstallResult(success: Bool) {
        let alert = NSAlert()
        if success {
            alert.alertStyle = .informational
            alert.messageText = "gifski Installed ✅"
            alert.informativeText = "gifski is ready. GIF conversions will now use gifski for best quality."
        } else {
            alert.alertStyle = .warning
            alert.messageText = "Installation Failed"
            alert.informativeText = """
                Could not install gifski automatically.
                Please run in Terminal:
                \(brewCommand)
                """
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
