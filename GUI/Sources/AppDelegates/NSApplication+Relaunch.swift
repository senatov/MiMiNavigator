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
    /// Relaunch the app: spawn a new instance then terminate this one.
    /// The new instance picks up all newly saved security-scoped bookmarks.
    func relaunch() {
        guard let executableURL = Bundle.main.executableURL else {
            log.error("[Relaunch] cannot resolve executableURL")
            return
        }
        log.info("[Relaunch] relaunching from \(executableURL.path)")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try task.run()
        } catch {
            log.error("[Relaunch] open failed: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}
