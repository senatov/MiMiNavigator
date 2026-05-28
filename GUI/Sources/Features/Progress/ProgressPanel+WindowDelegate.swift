// ProgressPanel+WindowDelegate.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 28.05.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: NSWindowDelegate hooks for ProgressPanel.

import AppKit

// MARK: - NSWindowDelegate

extension ProgressPanel: NSWindowDelegate {
    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        MainActor.assumeIsolated {
            hide()
        }
        return false
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard panel != nil else { return }
            registerUserInteraction(source: "resize")
            persistFrameForCurrentOperation()
        }
    }

    nonisolated func windowDidMove(_ notification: Notification) {
        MainActor.assumeIsolated {
            registerUserInteraction(source: "move")
            persistFrameForCurrentOperation()
        }
    }

    nonisolated func windowDidResignKey(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard panel?.isVisible == true else { return }
            log.debug("[ProgressPanel] ignored resign key")
        }
    }
}
