// NSApplication+Relaunch.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 06.03.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Relaunch helper — terminates current process and relaunches the app.
//   Used after granting new security-scoped bookmarks so the sandbox kernel
//   can accept the new access tokens on next startup.

import AppKit

// MARK: - NSApplication+Relaunch
extension NSApplication {
    // MARK: - Relaunch
    func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        guard !bundlePath.isEmpty else {
            log.error("[Relaunch] cannot resolve bundle path")
            return
        }
        let processIdentifier = ProcessInfo.processInfo.processIdentifier
        let script = """
        old_pid="$1"
        app_path="$2"
        while /bin/kill -0 "$old_pid" 2>/dev/null; do
            /bin/sleep 0.1
        done
        exec /usr/bin/open "$app_path"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/zsh")
        helper.arguments = ["-c", script, "mimi-relaunch", String(processIdentifier), bundlePath]
        do {
            try helper.run()
        } catch {
            log.error("[Relaunch] helper launch failed: \(error.localizedDescription)")
            return
        }
        log.info("[Relaunch] helper started oldProcess=\(processIdentifier) bundle='\(bundlePath)'")
        SettingsCoordinator.shared.close()
        terminate(nil)
    }
}
