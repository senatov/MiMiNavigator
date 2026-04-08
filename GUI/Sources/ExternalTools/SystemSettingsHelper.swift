// SystemSettingsHelper.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Deep-links into macOS System Settings → Privacy & Security.
//   Uses x-apple.systempreferences: URL scheme (Ventura+) or
//   com.apple.preference.security anchor (Monterey).

import AppKit


// MARK: - SystemSettingsHelper

enum SystemSettingsHelper {

    /// Full Disk Access — needed for protected dirs
    static func openFullDiskAccess() {
        openPrivacy("Privacy_AllFiles")
    }


    /// Accessibility — needed for some automation
    static func openAccessibility() {
        openPrivacy("Privacy_Accessibility")
    }


    /// Automation (AppleEvents) — Finder scripting
    static func openAutomation() {
        openPrivacy("Privacy_Automation")
    }


    /// Files and Folders — per-app folder grants
    static func openFilesAndFolders() {
        openPrivacy("Privacy_FilesAndFolders")
    }


    /// Developer Tools — for unsigned scripts
    static func openDeveloperTools() {
        openPrivacy("Privacy_DevTools")
    }


    // MARK: - Private

    private static func openPrivacy(_ anchor: String) {
        // Ventura+ (macOS 13+): x-apple.systempreferences URL scheme
        let urlStr = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        if let url = URL(string: urlStr) {
            log.info("[SystemSettings] opening \(anchor)")
            NSWorkspace.shared.open(url)
        } else {
            log.error("[SystemSettings] bad URL for anchor=\(anchor)")
        }
    }
}
