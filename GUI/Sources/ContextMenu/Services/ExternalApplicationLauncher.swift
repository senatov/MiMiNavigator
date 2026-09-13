// ExternalApplicationLauncher.swift
// MiMiNavigator
//
// Copyright © 2026 Senatov. All rights reserved.
// Description: Reliable document delivery to external macOS applications.

import AppKit
import Foundation

// MARK: - External Application Launcher
@MainActor
final class ExternalApplicationLauncher {
    static let shared = ExternalApplicationLauncher()
    private let workspace = NSWorkspace.shared
    private let vsCodeBundleIdentifiers: Set<String> = ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"]
    private init() {}
    // MARK: - Open Document
    func open(fileURL: URL, applicationURL: URL, bundleIdentifier: String?) {
        let bundleID = bundleIdentifier ?? Bundle(url: applicationURL)?.bundleIdentifier ?? "unknown"
        guard let currentApplicationURL = resolvedApplicationURL(preferredURL: applicationURL, bundleID: bundleID) else {
            log.error("[ExternalOpen] application unavailable bundle='\(bundleID)' savedPath='\(applicationURL.path)'")
            InAppNoticeCenter.shared.showError(
                title: "Application Not Found",
                message: "The selected application is no longer installed at its registered location."
            )
            return
        }
        let runningApp = workspace.runningApplications.first { $0.bundleIdentifier == bundleID }
        log.info("[ExternalOpen] request file='\(fileURL.path)' app='\(currentApplicationURL.path)' bundle='\(bundleID)' running=\(runningApp != nil)")
        if runningApp != nil, vsCodeBundleIdentifiers.contains(bundleID), launchVSCodeCLI(fileURL: fileURL, applicationURL: currentApplicationURL, bundleID: bundleID) {
            return
        }
        openWithWorkspace(fileURL: fileURL, applicationURL: currentApplicationURL, bundleID: bundleID)
    }
    // MARK: - Resolve Current Application
    private func resolvedApplicationURL(preferredURL: URL, bundleID: String) -> URL? {
        let registeredURL = workspace.urlForApplication(withBundleIdentifier: bundleID)
        for candidate in [registeredURL, preferredURL].compactMap({ $0 }) {
            let normalizedURL = candidate.standardizedFileURL
            guard FileManager.default.fileExists(atPath: normalizedURL.path) else { continue }
            guard Bundle(url: normalizedURL)?.bundleIdentifier == bundleID else { continue }
            return normalizedURL
        }
        return nil
    }
    // MARK: - VS Code IPC
    private func launchVSCodeCLI(fileURL: URL, applicationURL: URL, bundleID: String) -> Bool {
        let launcherURL = applicationURL.appendingPathComponent("Contents/Resources/app/bin/code")
        guard FileManager.default.isExecutableFile(atPath: launcherURL.path) else {
            log.warning("[ExternalOpen] VS Code launcher unavailable path='\(launcherURL.path)' — using NSWorkspace")
            return false
        }
        let process = Process()
        process.executableURL = launcherURL
        process.arguments = ["--reuse-window", fileURL.path]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { process in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            Task { @MainActor in
                if process.terminationStatus == 0 {
                    log.info("[ExternalOpen] VS Code IPC success bundle='\(bundleID)' file='\(fileURL.lastPathComponent)'")
                } else {
                    log.error("[ExternalOpen] VS Code IPC failed status=\(process.terminationStatus) message='\(message)'")
                    self.openWithWorkspace(fileURL: fileURL, applicationURL: applicationURL, bundleID: bundleID)
                }
            }
        }
        do {
            try process.run()
            log.debug("[ExternalOpen] VS Code IPC started pid=\(process.processIdentifier)")
            return true
        } catch {
            log.error("[ExternalOpen] VS Code IPC launch failed: \(error.localizedDescription)")
            return false
        }
    }
    // MARK: - Launch Services Fallback
    private func openWithWorkspace(fileURL: URL, applicationURL: URL, bundleID: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = true
        configuration.allowsRunningApplicationSubstitution = true
        workspace.open([fileURL], withApplicationAt: applicationURL, configuration: configuration) { runningApp, error in
            if let error {
                log.error("[ExternalOpen] NSWorkspace failed bundle='\(bundleID)' error='\(error.localizedDescription)'")
                Task { @MainActor in
                    InAppNoticeCenter.shared.showError(title: "Open Failed", message: error.localizedDescription)
                }
                return
            }
            log.info("[ExternalOpen] NSWorkspace success bundle='\(bundleID)' pid=\(runningApp?.processIdentifier ?? -1) terminated=\(runningApp?.isTerminated ?? true)")
        }
    }
}
