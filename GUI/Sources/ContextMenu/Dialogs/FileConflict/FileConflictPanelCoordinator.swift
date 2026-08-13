// FileConflictPanelCoordinator.swift
// MiMiNavigator
//
// Created by Iakov Senatov on 19.07.2026.
// Copyright © 2026 Senatov. All rights reserved.
// Description: Presents file conflicts in a standalone macOS utility panel.

import AppKit
import SwiftUI

// MARK: - File Conflict Panel Coordinator

@MainActor
final class FileConflictPanelCoordinator: NSObject, NSWindowDelegate {
    static let shared = FileConflictPanelCoordinator()
    private var panel: NSPanel?
    private var continuation: CheckedContinuation<BatchConflictDecision, Never>?

    // MARK: - Present

    func present(conflict: FileConflictInfo, remainingCount: Int) async -> BatchConflictDecision {
        cancelPendingPresentation()
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            openPanel(conflict: conflict, remainingCount: remainingCount)
        }
    }

    // MARK: - Open Panel

    private func openPanel(conflict: FileConflictInfo, remainingCount: Int) {
        let content = FileConflictDialog(
            conflict: conflict,
            remainingCount: remainingCount,
            onResolve: { [weak self] decision in self?.complete(with: decision) }
        )
        let hostingView = NSHostingView(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 640, height: 360)),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.tabbingMode = .disallowed
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        PanelTitleHelper.applyIconTitle(to: panel, systemImage: "doc.badge.exclamationmark", title: "File Conflict")
        let fittingSize = hostingView.fittingSize
        panel.setContentSize(NSSize(width: 640, height: max(320, fittingSize.height)))
        center(panel)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    // MARK: - Complete

    private func complete(with decision: BatchConflictDecision) {
        guard let continuation else { return }
        self.continuation = nil
        let panel = self.panel
        self.panel = nil
        panel?.delegate = nil
        panel?.close()
        continuation.resume(returning: decision)
    }

    // MARK: - Cancel Pending Presentation

    private func cancelPendingPresentation() {
        guard continuation != nil else { return }
        complete(with: BatchConflictDecision(resolution: .stop, applyToAll: false))
    }

    // MARK: - Center

    private func center(_ panel: NSPanel) {
        guard let host = NSApp.mainWindow else {
            panel.center()
            return
        }
        let x = host.frame.midX - panel.frame.width / 2
        let y = host.frame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let continuation else { return }
        self.continuation = nil
        panel = nil
        continuation.resume(returning: BatchConflictDecision(resolution: .stop, applyToAll: false))
    }
}
