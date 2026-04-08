// AutomationPermissionChecker.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Checks Automation (Apple Events) permission for target apps.
//   Uses AEDeterminePermissionToAutomateTarget to probe TCC status
//   without triggering the system alert. Returns .authorized / .denied / .notDetermined.

import AppKit
import Carbon


// MARK: - AutomationPermissionStatus

enum AutomationPermissionStatus: Sendable {
    case authorized
    case denied
    case notDetermined
}


// MARK: - AutomationPermissionChecker

enum AutomationPermissionChecker {

    // MARK: - Constants

    private static let wildcard = typeWildCard

    /// Target apps that MiMiNavigator sends Apple Events to
    static let targetBundleIDs: [(id: String, name: String)] = [
        ("com.apple.systemevents", "System Events"),
        ("com.apple.finder", "Finder"),
    ]


    /// Check permission for a single target app without triggering the TCC alert.
    /// Uses AEDeterminePermissionToAutomateTarget (macOS 10.14+).
    static func checkPermission(for bundleID: String) -> AutomationPermissionStatus {
        guard let target = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            // app not running — can't check, assume not determined
            return .notDetermined
        }
        guard var targetDesc = createTargetDescriptor(for: target.processIdentifier) else {
            return .notDetermined
        }
        defer { AEDisposeDesc(&targetDesc) }
        let status = AEDeterminePermissionToAutomateTarget(
            &targetDesc,
            wildcard,
            wildcard,
            false   // askUserIfNeeded = false → don't show system alert
        )
        switch status {
        case noErr:
            return .authorized
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(procNotFound):
            return .notDetermined
        default:
            log.debug("[AutomationPerm] \(bundleID) status=\(status)")
            return .notDetermined
        }
    }


    /// Check all target apps, return true if ALL are authorized
    static func allAuthorized() -> Bool {
        targetBundleIDs.allSatisfy { checkPermission(for: $0.id) == .authorized }
    }


    /// Ask permission for a target app by triggering a harmless AE.
    /// This WILL show the TCC alert if not yet authorized — call only from explicit user action.
    static func requestPermission(for bundleID: String) {
        guard let target = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            // launch the target first so we can send it an event
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                log.error("[AutomationPerm] cannot resolve URL for \(bundleID)")
                return
            }

            let config = NSWorkspace.OpenConfiguration()
            config.activates = false

            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
                if let error {
                    log.error("[AutomationPerm] failed to launch \(bundleID): \(error)")
                } else {
                    log.info("[AutomationPerm] launched \(bundleID) — will retry permission check")
                }
            }
            return
        }
        guard var targetDesc = createTargetDescriptor(for: target.processIdentifier) else {
            return
        }
        defer { AEDisposeDesc(&targetDesc) }
        // ask with alert this time
        let _ = AEDeterminePermissionToAutomateTarget(
            &targetDesc,
            wildcard,
            wildcard,
            true    // askUserIfNeeded = true → shows TCC dialog
        )
    }

    // MARK: - Private Helpers

    private static func createTargetDescriptor(for pid: pid_t) -> AEAddressDesc? {
        var pidValue = pid
        var desc = AEAddressDesc()

        let err = AECreateDesc(
            typeKernelProcessID,
            &pidValue,
            MemoryLayout<pid_t>.size,
            &desc
        )

        guard err == noErr else {
            log.warning("[AutomationPerm] AECreateDesc failed: \(err)")
            return nil
        }

        return desc
    }
}
