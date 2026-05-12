// AutomationPermissionChecker.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 08.04.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Checks & requests Automation (Apple Events) permission for target apps.
//   Uses AEDeterminePermissionToAutomateTarget to probe TCC status
//   without triggering the system alert. Prewarms all targets with
//   a harmless NSAppleScript to batch-trigger TCC dialogs at onboarding.

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

    /// Target apps that MiMiNavigator sends Apple Events to.
    /// Must match temporary-exception.apple-events in entitlements.
    static let targetBundleIDs: [(id: String, name: String)] = [
        ("com.apple.systemevents", "System Events"),
        ("com.apple.finder", "Finder"),
        ("com.apple.Terminal", "Terminal"),
        ("com.apple.dt.FileMerge", "FileMerge"),
    ]



    /// Harmless AppleScript per target — triggers TCC dialog on first run.
    /// Each script does absolute minimum: just reads a property that always exists.
    private static let prewarmScripts: [String: String] = [
        "com.apple.systemevents": "tell application \"System Events\" to get name of current user",
        "com.apple.finder": "tell application \"Finder\" to get name of startup disk",
        "com.apple.Terminal": "tell application \"Terminal\" to get name",
        "com.apple.dt.FileMerge": "tell application \"FileMerge\" to get name",
    ]



    /// Check permission for a single target app without triggering the TCC alert.
    static func checkPermission(for bundleID: String) -> AutomationPermissionStatus {
        guard let target = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
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
            false
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



    /// Prewarm all targets by executing a harmless AppleScript for each.
    /// This triggers the TCC dialog if permission wasn't granted yet.
    /// Skips already-authorized targets and targets that aren't installed.
    /// Call from explicit user action only (onboarding "Grant Access" btn).
    static func prewarmAllTargets() {
        for target in targetBundleIDs {
            let status = checkPermission(for: target.id)
            if status == .authorized {
                log.info("[AutomationPerm] \(target.name) already authorized, skip")
                continue
            }
            prewarmTarget(bundleID: target.id, name: target.name)
        }
    }



    /// Request permission for a single target by running its prewarm script.
    /// Falls back to AEDeterminePermissionToAutomateTarget if no script defined.
    static func requestPermission(for bundleID: String) {
        prewarmTarget(bundleID: bundleID, name: bundleID)
    }



    // MARK: - Private

    /// Run the harmless AppleScript for one target to trigger TCC.
    /// If target not running, try to launch it first (hidden, no activation).
    private static func prewarmTarget(bundleID: String, name: String) {
        guard let scriptSource = prewarmScripts[bundleID] else {
            log.warning("[AutomationPerm] no prewarm script for \(name), using AE probe")
            aeProbeRequest(bundleID: bundleID)
            return
        }
        // ensure target is running (Finder/SysEvents usually are, Terminal/FileMerge maybe not)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.isEmpty {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                log.warning("[AutomationPerm] \(name) not installed, skip")
                return
            }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.hides = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error {
                    log.warning("[AutomationPerm] failed to launch \(name): \(error.localizedDescription)")
                } else {
                    // retry after brief delay for process to register
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        executePrewarmScript(scriptSource, name: name)
                    }
                }
            }
            return
        }
        executePrewarmScript(scriptSource, name: name)
    }



    /// Execute NSAppleScript — this is what actually triggers the TCC dialog.
    private static func executePrewarmScript(_ source: String, name: String) {
        let script = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        log.info("[AutomationPerm] prewarm \(name) — executing AppleScript")
        script?.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? -1
            // -1743 = "not permitted" = TCC denied, expected on first-ever call
            if code == -1743 {
                log.info("[AutomationPerm] \(name) TCC dialog shown or denied (code -1743)")
            } else {
                log.warning("[AutomationPerm] \(name) script error: \(errorInfo)")
            }
        } else {
            log.info("[AutomationPerm] \(name) prewarm OK — authorized")
        }
    }



    /// Fallback: AE probe with askUserIfNeeded = true
    private static func aeProbeRequest(bundleID: String) {
        guard let target = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return
        }
        guard var targetDesc = createTargetDescriptor(for: target.processIdentifier) else {
            return
        }
        defer { AEDisposeDesc(&targetDesc) }
        let _ = AEDeterminePermissionToAutomateTarget(
            &targetDesc, wildcard, wildcard, true
        )
    }



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
