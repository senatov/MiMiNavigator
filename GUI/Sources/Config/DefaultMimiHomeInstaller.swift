// DefaultMimiHomeInstaller.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 13.06.2026.
// Description: Installs missing ~/.mimi configuration files from bundled defaults.

import Foundation

// MARK: - Default Mimi Home Installer
enum DefaultMimiHomeInstaller {
    private static let fileNames = [
        "archive_prefs.json",
        "column_layout.json",
        "defaults.json",
        "preferences.json",
        "progress_appearance.json"
    ]

    // MARK: - Install Missing Files
    static func installMissingFiles() {
        let fileManager = FileManager.default
        guard let bundleURL = Bundle.main.url(forResource: "DefaultMimiHome", withExtension: "bundle") else {
            log.warning("[Defaults] DefaultMimiHome.bundle is missing")
            return
        }
        let sourceDirectory = bundleURL.appendingPathComponent(".mimi", isDirectory: true)
        let targetDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".mimi", isDirectory: true)
        do {
            try fileManager.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            for fileName in fileNames {
                let targetURL = targetDirectory.appendingPathComponent(fileName)
                guard !fileManager.fileExists(atPath: targetURL.path) else { continue }
                let sourceURL = sourceDirectory.appendingPathComponent(fileName)
                guard fileManager.fileExists(atPath: sourceURL.path) else {
                    log.warning("[Defaults] bundled file is missing: \(fileName)")
                    continue
                }
                try fileManager.copyItem(at: sourceURL, to: targetURL)
                log.info("[Defaults] installed ~/.mimi/\(fileName)")
            }
        } catch {
            log.error("[Defaults] failed to install bundled configuration: \(error.localizedDescription)")
        }
    }
}
